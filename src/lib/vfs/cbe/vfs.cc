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
#include <cbe/library.h>
#include <cbe/external_crypto.h>

namespace Vfs_cbe {
	using namespace Vfs;
	using namespace Genode;

  class  Block_file_system;
	struct Local_factory;
	class  File_system;
}


// XXX remove later
#define DEBUG 1
#if defined(DEBUG)
#define ERR(...)  Genode::error(__func__, ":", __LINE__, " ", __VA_ARGS__);
#define FLOG(...) Genode::log("\033[35;1m", __func__, ":", __LINE__, " ", __VA_ARGS__);
#define BLOG(...) Genode::log("\033[34;1m", __func__, ":", __LINE__, " ", __VA_ARGS__);
#define LOG(...)  Genode::log("\033[37;1m", __func__, ":", __LINE__, " ", __VA_ARGS__);
#define CBE(...)  Genode::log("\033[36m", __func__, ":", __LINE__, " ", __VA_ARGS__);
#else
#define ERR(...)
#define FLOG(...)
#define BLOG(...)
#define LOG(...)
#define CBE(...)
#endif


extern "C" void adainit();


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

		struct Crypto_Data
		{
			Cbe::Block_data items[1];
		} _crypto_data;
		External::Crypto _crypto { };

		Constructible<Cbe::Library> _cbe;

		Cbe::Superblock_index _cur_sb { Cbe::Superblock_index::INVALID };
		Cbe::Superblocks      _super_blocks { };

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

		Cbe::Superblock_index _read_superblocks(Cbe::Superblocks &sbs)
		{
			Cbe::Generation        last_gen = 0;
			Cbe::Superblock_index most_recent_sb { Cbe::Superblock_index::INVALID };

			static_assert(sizeof (Cbe::Superblock) == Cbe::BLOCK_SIZE,
			              "Super-block size mistmatch");

			/*
			 * Read all super block slots and use the most recent one.
			 */
			for (uint64_t i = 0; i < Cbe::NUM_SUPER_BLOCKS; i++) {
				file_size bytes = 0;
				_backend->seek(i * Cbe::BLOCK_SIZE);
				Cbe::Superblock &dst = sbs.block[i];
				if (_backend->read((char *)&dst, Cbe::BLOCK_SIZE, bytes) != File_io_service::READ_OK)
					return Cbe::Superblock_index();

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
			External::Crypto    &_crypto;
			Crypto_Data         &_crypto_data;
			Cbe::Library        &_cbe;
			Cbe::Time           &_time;
			Single_vfs_handle   *_backend { };
			Cbe::Request         _backend_request { };

			bool _show_progress { false };
			bool _show_if_progress { false };

			Vfs_handle(Directory_service &ds,
			           File_io_service   &fs,
			           Genode::Allocator &alloc,
			           External::Crypto  &crypto,
			           Crypto_Data       &crypto_data,
			           Cbe::Library      &cbe,
			           Cbe::Time         &time,
			           Single_vfs_handle *backend,
			           bool show_progress)
			: Single_vfs_handle(ds, fs, alloc, 0),
			  _alloc(alloc),
			  _crypto(crypto), _crypto_data(crypto_data),
			  _cbe(cbe),
			  _time(time),
			  _backend(backend),
			  _show_progress(show_progress)
			{ }

			enum Request_state { NONE, PENDING, IO_PENDING, ERROR };
			Request_state _state { NONE };

			struct Invalid_Request : Genode::Exception { };

			Cbe::Request cbe_request(char *data, file_size count,
			                         Cbe::Request::Operation operation)
			{
				file_size const offset = seek();

				if ((offset % Cbe::BLOCK_SIZE) != 0) {
					Genode::error("offset not multiple of block size");
					throw Invalid_Request();
				}

				if (count < Cbe::BLOCK_SIZE) {
					Genode::error("count less than block size");
					throw Invalid_Request();
				}

				return Cbe::Request {
					.operation    = operation,
					.success      = Cbe::Request::Success::FALSE,
					.block_number = offset / Cbe::BLOCK_SIZE,
					.offset       = (uint64_t)data,
					.count        = (uint32_t)(count / Cbe::BLOCK_SIZE),
				};
			}

			void backend_read(Cbe::Request &request)
			{
				file_size count = request.count * Cbe::BLOCK_SIZE;
				file_size out = 0;

				_backend_request = request;

				_cbe.io_data_read_in_progress(request);

				_backend->seek(request.block_number * Cbe::BLOCK_SIZE);

				char *buf = 0;
				_alloc.alloc(count, &buf);

				if (_backend->read(buf, count, out) == READ_QUEUED) {
					_alloc.free(buf, count);
					_state = IO_PENDING;
					return;
				}

				Cbe::Block_data &data = *reinterpret_cast<Cbe::Block_data *>(buf);
				request.success = Cbe::Request::Success::TRUE;
				_cbe.supply_io_data(request, data);
				_alloc.free(buf, count);

				_backend_request = Cbe::Request { };
			}

			void backend_write(Cbe::Request &request)
			{
				file_size count = request.count * Cbe::BLOCK_SIZE;
				file_size out = 0;

				_backend_request = request;

				char *buf;
				_alloc.alloc(count, &buf);
				Cbe::Block_data &data = *reinterpret_cast<Cbe::Block_data *>(buf);
				_cbe.obtain_io_data(request, data);

				_backend->seek(request.block_number * Cbe::BLOCK_SIZE);

				try {
					_backend->write(buf, count, out);
				} catch (Insufficient_buffer) {
					_alloc.free(buf, count);
					_state = IO_PENDING;
					return;
				}

				request.success = Cbe::Request::Success::TRUE;
				_cbe.ack_io_data_to_write(request);
				_alloc.free(buf, count);
				_backend_request = Cbe::Request { };
			}

			void handle_request(Cbe::Request &request)
			{
				bool progress = false;
				Cbe::Virtual_block_address const vba = request.block_number;

				if (vba > _cbe.max_vba()) {
					warning("reject request with out-of-range virtual block address ", vba);
					_state = ERROR;
					return;
				}

				if (_cbe.client_request_acceptable() && _state == NONE) {
					_cbe.submit_client_request(request);
					_state = PENDING;
					progress = true;
				}

				while (true) {

					while (true) {
						Cbe::Request const cbe_request = _cbe.peek_completed_client_request();
						if (!cbe_request.valid()) { break; }

						_cbe.drop_completed_client_request(cbe_request);
						_state = NONE;
						progress = true;
					}

					_cbe.execute(_time.timestamp());
					progress |= _cbe.execute_progress();

					/* read */
					Cbe::Request cbe_request = _cbe.client_data_ready();
					if (cbe_request.valid() && cbe_request.read()) {

						uint64_t const prim_index = _cbe.give_data_index(cbe_request);
						if (prim_index == ~0ull) {
							Genode::error("prim_index invalid: ", cbe_request);
							_state = ERROR;
							return;
						}

						Cbe::Block_data &data = *reinterpret_cast<Cbe::Block_data*>(
							cbe_request.offset + (prim_index * Cbe::BLOCK_SIZE));

						_cbe.obtain_client_data(cbe_request, data);

						progress = true;
					}

					/* write */
					cbe_request = _cbe.client_data_required();
					if (cbe_request.valid() && cbe_request.write()) {
						uint64_t const prim_index = _cbe.give_data_index(cbe_request);
						if (prim_index == ~0ull) {
							Genode::error("prim_index invalid: ", cbe_request);
							_state = ERROR;
							return;
						}

						Cbe::Block_data &data = *reinterpret_cast<Cbe::Block_data*>(
							cbe_request.offset + (prim_index * Cbe::BLOCK_SIZE));

						progress = _cbe.supply_client_data(_time.timestamp(), cbe_request, data);

						progress = true;
					}

					cbe_request = _cbe.io_data_required();
					if (cbe_request.valid() && !_backend_request.valid()) {
						backend_read(cbe_request);
						progress = true;
					}

					cbe_request = _cbe.has_io_data_to_write();
					if (cbe_request.valid() && !_backend_request.valid()) {
						backend_write(cbe_request);
						progress = true;
					}

					progress |= _crypto.execute();

					/* encrypt */
					do {
						Cbe::Request const request = _cbe.crypto_data_required();
						if (!request.valid()) { break; }
						if (!_crypto.encryption_request_acceptable()) { break; }

						if (!_cbe.obtain_crypto_plain_data(request, _crypto_data.items[0])) { break; }

						_crypto.submit_encryption_request(request, _crypto_data.items[0], 0);
						progress |= true;
					} while (0);

					while (true) {
						Cbe::Request const request = _crypto.peek_completed_encryption_request();
						if (!request.valid()) { break; }

						if (!_crypto.supply_cipher_data(request, _crypto_data.items[0])) { break; }

						_cbe.supply_crypto_cipher_data(request, _crypto_data.items[0]);
						progress |= true;
					}

					/* decrypt */
					do {
						Cbe::Request const request = _cbe.has_crypto_data_to_decrypt();
						if (!request.valid()) { break; }
						if (!_crypto.decryption_request_acceptable()) { break; }

						if (!_cbe.obtain_crypto_cipher_data(request, _crypto_data.items[0])) { break; }

						_crypto.submit_decryption_request(request, _crypto_data.items[0], 0);
						progress |= true;
					} while (0);

					while (true) {
						Cbe::Request const request = _crypto.peek_completed_decryption_request();
						if (!request.valid()) { break; }

						if (!_crypto.supply_plain_data(request, _crypto_data.items[0])) { break; }

						_cbe.supply_crypto_plain_data(request, _crypto_data.items[0]);
						progress |= true;
					}

					if (!progress) break;
					progress = false;
				}

			}

			Read_result read(char *dst, file_size count,
			                 file_size &out_count) override
			{
				/* request already pending, try again later */
				if (!_cbe.client_request_acceptable() || _state != NONE) {
					return READ_QUEUED;
				}

				using Operation = Cbe::Request::Operation;
				Cbe::Request request { };
				try {
					request = cbe_request(dst, count, Operation::READ);
				} catch (Invalid_Request) {
					_state = NONE;
					return READ_ERR_IO;
				}

				handle_request(request);

				/* retry on next I/O signal */
				if (_state == PENDING) {
					return READ_QUEUED;
				}

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
				/* request already pending, try again later */
				if (!_cbe.client_request_acceptable() || _state != NONE) {
					throw Insufficient_buffer();
				}

				using Operation = Cbe::Request::Operation;
				Cbe::Request request { };

				try {
					request = cbe_request(const_cast<char *>(src), count, Operation::WRITE);
				} catch (Invalid_Request) {
					_state = NONE;
					return WRITE_ERR_IO;
				}
				handle_request(request);

				/* retry on next I/O signal */
				if (_state == PENDING) {
					throw Insufficient_buffer();
				}

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
		{
			_read_config(config);

			External::Crypto::Key_data key { };
			Genode::memcpy(key.value, "All your base are belong to us  ", 32);
			_crypto.set_key(0, 0, key);
		}


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
			*out_handle = new (alloc) Vfs_handle(*this, *this, alloc, _crypto, _crypto_data, *_cbe,
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
	Genode::Thread::myself()->stack_size(64*1024);

	adainit();

	Cbe::assert_valid_object_size<Cbe::Library>();

	static Factory factory;
	return &factory;
}
