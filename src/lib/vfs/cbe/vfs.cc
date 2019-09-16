/*
 * Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
 *
 * This file is part of the Consistent Block Encrypter project, which is
 * distributed under the terms of the GNU Affero General Public License
 * version 3.
 */

/* Genode includes */
#include <vfs/dir_file_system.h>
#include <vfs/single_file_system.h>
#include <util/xml_generator.h>

/* repo includes */
#include <util/sha256_4k.h>

/* cbe includes */
#include <block/request_stream.h> //XXX: library depends on this
#include <cbe/library.h>

namespace Vfs_cbe {
	using namespace Vfs;
	using namespace Genode;

  class  Block_file_system;
	struct Local_factory;
	class  File_system;
}

extern "C" void print_u8(unsigned char const u) { Genode::log(u); }

extern "C" void print_cstring(char const *s, Genode::size_t len)
{
	Genode::log(Genode::Cstring(s, len));
}

class Vfs_cbe::Block_file_system : public Single_file_system
{
	private:

		typedef String<32> Config;
		Vfs::Env          &_env;
		Single_vfs_handle *_backend { nullptr };

		Constructible<Cbe::Library> _cbe;

		Cbe::Super_block_index _cur_sb { Cbe::Super_block_index::INVALID };
		Cbe::Super_blocks      _super_blocks { };

		Cbe::Time _time { _env.env() };

		/* configuration options */
		bool                 _show_progress { false };
		Cbe::Time::Timestamp _sync_interval { 1000 * 5};
		Cbe::Time::Timestamp _secure_interval { 1000 * 30 };
		Config               _block_device { "/dev/block" };

		static Config _config()
		{
			char buf[Config::capacity()] { };
			Xml_generator xml(buf, sizeof(buf), type_name(), [&] () { });

			return Config(Cstring(buf));
		}

		void _read_config(Xml_node config)
		{
			_show_progress   = config.attribute_value("show_progress", false);
			_sync_interval   = config.attribute_value("sync_interval", 5u) * 1000;
			_secure_interval = config.attribute_value("secure_interval", 30u) * 1000;
			_block_device    = config.attribute_value("block", _block_device);
		}

		Cbe::Super_block_index _read_superblocks(Cbe::Super_blocks &sbs)
		{
			Cbe::Generation        last_gen = 0;
			Cbe::Super_block_index most_recent_sb { Cbe::Super_block_index::INVALID };

			static_assert(sizeof (Cbe::Super_block) == Cbe::BLOCK_SIZE,
			              "Super-block size mistmatch");

			/*
			 * Read all super block slots and use the most recent one.
			 */
			for (uint64_t i = 0; i < Cbe::NUM_SUPER_BLOCKS; i++) {
				file_size bytes = 0;
				_backend->seek(i * Cbe::BLOCK_SIZE);
				Cbe::Super_block &dst = sbs.block[i];
				if (_backend->read((char *)&dst, Cbe::BLOCK_SIZE, bytes) != File_io_service::READ_OK)
					return Cbe::Super_block_index();

				/*
				 * For now this always selects the last SB if the generation
				 * is the same and is mostly used for finding the initial SB
				 * with generation == 0.
				 */
				if (dst.valid() && dst.last_secured_generation >= last_gen) {
					most_recent_sb.value = i;
					last_gen = dst.last_secured_generation;
				}

				Sha256_4k::Hash hash { };
				Sha256_4k::Data const &data = *reinterpret_cast<Sha256_4k::Data const*>(&dst);
				Sha256_4k::hash(data, hash);
				Genode::log("SB[", i, "] hash: ", hash);
			}

			return most_recent_sb;
		}

	public:

		struct Vfs_handle : Single_vfs_handle
		{
			Genode::Allocator   &_alloc;
			Cbe::Library        &_cbe;
			Cbe::Time           &_time;
			Single_vfs_handle   *_backend { };
			Cbe::Request         _backend_request { };

			bool _show_progress { false };
			bool _show_if_progress { false };

			Vfs_handle(Directory_service &ds,
			           File_io_service   &fs,
			           Genode::Allocator &alloc,
			           Cbe::Library      &cbe,
			           Cbe::Time         &time,
			           Single_vfs_handle *backend,
			           bool show_progress)
			: Single_vfs_handle(ds, fs, alloc, 0),
			  _alloc(alloc),
			  _cbe(cbe),
			  _time(time),
			  _backend(backend),
			  _show_progress(show_progress)
			{ }

			enum Request_state { NONE, PENDING, ERROR };
			Request_state _state { NONE };

			Cbe::Request cbe_request(char *data, file_size count,
			                         Cbe::Request::Operation operation)
			{
				return Cbe::Request {
					.operation    = operation,
					.success      = Cbe::Request::Success::FALSE,
					.block_number = seek() / Cbe::BLOCK_SIZE,
					.offset       = (uint64_t)data,
					.count        = (uint32_t)(count / Cbe::BLOCK_SIZE),
				};
			}

			void backend_read(Cbe::Request &request)
			{
				log(__func__, " request: ", request);
				file_size count = request.count * Cbe::BLOCK_SIZE;
				file_size out = 0;

				_backend_request = request;

				_cbe.take_read_data(request);

				_backend->seek(request.block_number * Cbe::BLOCK_SIZE);

				char *buf = 0;
				_alloc.alloc(count, &buf);

				if (_backend->read(buf, count, out) == READ_QUEUED) {
					_alloc.free(buf, count);
					_state = PENDING;
					return;
				}

				log("back read data: ", Hex(buf[0]));

				log("backend read: ", out);

				Cbe::Block_data &data = *reinterpret_cast<Cbe::Block_data *>(buf);
				request.success = Cbe::Request::Success::TRUE;
				_cbe.ack_read_data(request, data);
				_alloc.free(buf, count);

				_backend_request = Cbe::Request { };
			}

			void backend_write(Cbe::Request &request)
			{
				log(__func__, " request: ", request);
				file_size count = request.count * Cbe::BLOCK_SIZE;
				file_size out = 0;

				_backend_request = request;

				char *buf;
				_alloc.alloc(count, &buf);
				Cbe::Block_data &data = *reinterpret_cast<Cbe::Block_data *>(buf);
				_cbe.take_write_data(request, data);

				_backend->seek(request.block_number * Cbe::BLOCK_SIZE);

				try {
					log("back write data: ", Hex(buf[0]));
					_backend->write(buf, count, out);
				} catch (Insufficient_buffer) {
					_alloc.free(buf, count);
					_state = PENDING;
					return;
				}

				log("backend write: ", out);

				request.success = Cbe::Request::Success::TRUE;
				_cbe.ack_write_data(request);
				_alloc.free(buf, count);
				_backend_request = Cbe::Request { };
			}

			void handle_request(Cbe::Request &request)
			{
				warning(__func__, " ENTER state: ", (int)_state," ",  request);
				bool progress = false;
				Cbe::Virtual_block_address const vba = request.block_number;

				if (vba > _cbe.max_vba()) {
					warning("reject request with out-of-range virtual block address ", vba);
					_state = ERROR;
					return;
				}

				if (_cbe.request_acceptable() && _state != PENDING) {
					_cbe.submit_request(request);
					progress = true;
				}

				_state = NONE;

				while (true) {

					for(Cbe::Request cbe_request = _cbe.peek_completed_request();
					    cbe_request.valid(); cbe_request = _cbe.peek_completed_request()) {
						_cbe.drop_completed_request(cbe_request);
						progress = true;
					}

					_cbe.execute(_time.timestamp());
					progress |= _cbe.execute_progress();

					Cbe::Request cbe_request = _cbe.have_data();
					if (cbe_request.valid()) {

						uint64_t const prim_index = _cbe.give_data_index(cbe_request);
						if (prim_index == ~0ull) {
							Genode::error("prim_index invalid: ", cbe_request);
							_state = ERROR;
							return;
						}

						Cbe::Block_data &data = *reinterpret_cast<Cbe::Block_data*>(cbe_request.offset + (prim_index * Cbe::BLOCK_SIZE));

						if (cbe_request.read()) {
							/* XXX evaluate 'progress' */
							_cbe.give_read_data(cbe_request, data);
						} else

						if (cbe_request.write()) {
							_cbe.give_write_data(0, cbe_request, data);
						}
						char *DATA = (char *)(cbe_request.offset + (prim_index * Cbe::BLOCK_SIZE));
						uint64_t b = cbe_request.block_number;
						uint32_t c = cbe_request.count;
						log("data: ", cbe_request.read() ? "read" :  "write", ": block: ", b,  " count: ", c, " idx: ", prim_index);
						DATA[1] = 0;
						log("DATA[0]: ", Hex(DATA[0]));
						progress = true;
					}

					cbe_request = _backend_request.valid() ? _backend_request : _cbe.need_data();
					if (cbe_request.valid()) {
						if (cbe_request.read())
							backend_read(cbe_request);

						else if(cbe_request.write())
							backend_write(cbe_request);

						if (_state == PENDING) return;

						progress = true;
					}

					if (!progress) break;
					progress = false;
				}
			}

			Read_result read(char *dst, file_size count,
			                 file_size &out_count) override
			{
				Genode::warning(__PRETTY_FUNCTION__, " called");

				using Operation = Cbe::Request::Operation;
				Cbe::Request request = cbe_request(dst, count, Operation::READ);

				handle_request(request);

				/* retry on next I/O signal */
				if (_state == PENDING) return READ_QUEUED;

				if (_state == ERROR) {
					_state = NONE;
					return READ_ERR_IO;
				}

				_state = NONE;

				out_count = count;
				return READ_OK;
			}

			Write_result write(char const *src, file_size count,
			                   file_size &out_count) override
			{
				Genode::warning(__PRETTY_FUNCTION__, " called");
				log("write buf ", count, "bytes: ", src);
				using Operation = Cbe::Request::Operation;
				Cbe::Request request = cbe_request(const_cast<char *>(src), count, Operation::WRITE);

				handle_request(request);

				/* retry on next I/O signal */
				if (_state == PENDING) throw Insufficient_buffer();

				if (_state == ERROR) {
					_state = NONE;
					return WRITE_ERR_IO;
				}

				_state = NONE;

				out_count = count;
				return WRITE_OK;
			}

			bool read_ready() override
			{
				return true;
			}
		};

		Block_file_system(Vfs::Env &env, Xml_node config)
		: Single_file_system(NODE_TYPE_BLOCK_DEVICE, type_name(), _config().string()),
		  _env(env)
		{ _read_config(config); }


		/***************************
		 ** File-system interface **
		 ***************************/

		Open_result open(char const  *path, unsigned,
		                 Vfs::Vfs_handle **out_handle,
		                 Allocator   &alloc) override
		{
			if (!_single_file(path))
				return OPEN_ERR_UNACCESSIBLE;

			if (!_backend) {
				Open_result res = _env.root_dir().open(_block_device.string(), 0,
				                                       (Vfs::Vfs_handle **)&_backend,
				                                       _env.alloc());
				if (res != OPEN_OK) {
					error("cbe_fs: Could not open back end block device: '", _block_device, "'");
					return OPEN_ERR_UNACCESSIBLE;
				}

				_cur_sb = _read_superblocks(_super_blocks);

				if (!_cur_sb.valid()) {
					error("cbe_fs: No valid super block");
					return OPEN_ERR_UNACCESSIBLE;
				}

				_cbe.construct(_super_blocks, _cur_sb);
			}
			log("open: ", path);
			*out_handle = new (alloc) Vfs_handle(*this, *this, alloc, *_cbe,
			                                     _time, _backend, _show_progress);

			return OPEN_OK;
		}

		static char const *type_name() { return "block"; }
		char const *type() override { return type_name(); }
};


struct Vfs_cbe::Local_factory : File_system_factory
{
	Block_file_system _block_fs;

	Local_factory(Vfs::Env &env, Xml_node config)
	: _block_fs(env, config) { }

	Vfs::File_system *create(Vfs::Env&, Xml_node node) override
	{
		if (node.has_type(Block_file_system::type_name()))
			return &_block_fs;

		return nullptr;
	}
};


class Vfs_cbe::File_system : private Local_factory,
                             public Vfs::Dir_file_system
{
	private:

		typedef String<128> Config;

		static Config _config(Xml_node node)
		{
			char buf[Config::capacity()] { };
			/*
			 * TODO: Add snapshots
			 */
			Xml_generator xml(buf, sizeof(buf), "dir", [&] () {
				typedef String<64> Name;
				xml.attribute("name", node.attribute_value("name", Name()));
				xml.node("block", [&] () { });
			});

			Genode::log("CBE-dir XML:\n", (char const *) buf);
			return Config(Cstring(buf));
		}

	public:

		File_system(Vfs::Env &vfs_env, Genode::Xml_node node)
		: Local_factory(vfs_env, node),
		  Vfs::Dir_file_system(vfs_env, Xml_node(_config(node).string()), *this)
		{ }
};


/******************************
 ** Cbe::Time implementation **
 ******************************/

void Cbe::Time::_handle_sync_timeout(Genode::Duration)
{
	warning("Cbe::Time::_handle_sync_timeout not implemented");
}


void Cbe::Time::_handle_secure_timeout(Genode::Duration)
{
	warning("Cbe::Time::_handle_secure_timeout not implemented");
}


Cbe::Time::Time(Genode::Env &env) : _timer(env) { }


Cbe::Time::Timestamp Cbe::Time::timestamp()
{
	return _timer.curr_time().trunc_to_plain_ms().value;
}


/**************************
 ** VFS plugin interface **
 **************************/

extern "C" Vfs::File_system_factory *vfs_file_system_factory(void)
{
	struct Factory : Vfs::File_system_factory
	{
		Vfs::File_system *create(Vfs::Env &vfs_env,
		                         Genode::Xml_node node) override
		{
			try { return new (vfs_env.alloc())
				Vfs_cbe::File_system(vfs_env, node); }
			catch (...) { Genode::error("could not create 'cbe_fs' "); }
			return nullptr;
		}
	};

	/* the CBE library requires a stack larger than the default */
	Genode::Thread::myself()->stack_size(512*1024);

	Cbe::assert_valid_object_size<Cbe::Library>();

	static Factory factory;
	return &factory;
}
