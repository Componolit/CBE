/*
 * Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
 *
 * This file is part of the Consistent Block Encrypter project, which is
 * distributed under the terms of the GNU Affero General Public License
 * version 3.
 */

#ifndef _CBE_WRITE_BACK_MODULE_H_
#define _CBE_WRITE_BACK_MODULE_H_

/* local includes */
#include <cbe/types.h>


namespace Cbe { namespace Module {

	template <unsigned, typename> class Write_back;

} /* namespace Module */ } /* namespace Cbe */

template <unsigned N, typename T>
class Cbe::Module::Write_back
{
	public:

		struct Index
		{
			static constexpr Genode::uint32_t INVALID = ~0u;
			unsigned value;
			bool valid() const { return value != INVALID; }
		};

	private:

		struct Entry {
			Cbe::Block_data data { };
			uint32_t level { ~0u };
			Cbe::Physical_block_address old_pba { 0 };
			Cbe::Physical_block_address new_pba { 0 };

			bool in_progress { false };
			bool done { false };

			bool io_in_progress { false };
			bool io_done { false };

			Cbe::Tag tag { Cbe::Tag::INVALID_TAG };
		};

		/*
		 * _entry[0]               -> leaf node
		 * _entry[1] ... _entry[N] -> inner node
		 */
		Entry _entry[N] { };

		uint32_t _levels { 0 };
		bool _io { false };

		Cbe::Primitive _pending_primitive { };
		Cbe::Virtual_block_address _vba { ~0ull };
		Cbe::Generation _new_generation { 0 };

	public:

		Write_back() { }

		void copy_and_update(Cbe::Physical_block_address const pba,
		                     Cbe::Block_data const &data,
		                     Cbe::Module::Translation<T> &trans)
		{
			for (Genode::uint32_t i = 0; i < _levels; i++) {
				Entry &e = _entry[i];

				if (e.tag != Cbe::Tag::CACHE_TAG || e.old_pba != pba) {
					continue;
				}

				/* assert sizeof (e.data) == sizeof (data) */
				void const *src = (void const*)&data;
				void       *dst = (void*)&e.data;
				Genode::memcpy(dst, src, sizeof (e.data));

				/* save as long as only inner nodes in cache */
				Entry &e1 = _entry[i-1];

				/* get index from VBA in inner node */
				Genode::uint32_t const index = trans.index(_vba, i);
				T *t = reinterpret_cast<T*>(&e.data);

				Cbe::Physical_block_address const _old_pba = t[index].pba;
				Cbe::Generation             const _old_gen = t[index].gen;
				t[index].pba = e1.new_pba;
				t[index].gen = (_old_gen & Cbe::GEN_TYPE_MASK) | _new_generation;

				/* calculate hash for child */
				{
					Genode::error(__func__, ": ", _old_pba, " -> ", e1.new_pba, " hash");
					Sha256_4k::Data *data = reinterpret_cast<Sha256_4k::Data*>(&e1.data);
					Sha256_4k::Hash hash { };
					Sha256_4k::hash(*data, hash);
					Genode::memcpy(t[index].hash.values, hash.values, sizeof (hash));
				};

				Genode::error(i, ": ", _vba, " ", e.old_pba, " -> ", e.new_pba, " ", index);

				for (Genode::uint32_t i = 0; i < 4; i++) {
					Cbe::Physical_block_address pba = t[i].pba;
					Genode::log(__func__, ": ", pba);
				}

				Genode::log(__func__, ": ", i, " done");
				e.done = true;
				break;
			}
		}

		bool primitive_acceptable() const { return !_pending_primitive.valid(); }

		void submit_primitive(Primitive const &p, Cbe::Generation new_generation,
		                      Cbe::Virtual_block_address vba,
		                      Cbe::Physical_block_address *new_pba,
		                      Cbe::Physical_block_address *old_pba, uint32_t n, Block_data &d)
		{
			Genode::log(__func__, " p: ", p.block_number);

			_pending_primitive = p;
			_new_generation = new_generation;
			_vba = vba;

			_levels = n;
			_io = false;

			/* handle common members */
			for (Genode::uint32_t i = 0; i < n; i++) {
				Entry &e = _entry[i];

				Cbe::Physical_block_address phys = old_pba[i];
				Genode::log(" old[", i, "]: ", phys, " -> ", new_pba + i);

				e.old_pba = old_pba[i];
				e.new_pba = new_pba[i];
				e.in_progress = false;
				e.done        = false;
				e.io_in_progress = false;
				e.io_done        = false;
				e.tag = Cbe::Tag::CACHE_TAG;
			}

			/* the data or rather leave node is special */
			Entry &e = _entry[0];
			e.tag = Cbe::Tag::CRYPTO_TAG_ENCRYPT;
			void *dest = (void*)&e.data;
			Genode::memcpy(dest, &d, sizeof (e.data));
		}

		bool execute()
		{
			if (!_pending_primitive.valid()) { return false; }

			if (_io) { return false; }

			bool done = true;
			for (Genode::uint32_t i = 0; i < _levels; i++) {
				Entry &e = _entry[i];
				if (!e.done) {
					Genode::error(__func__, ": ", i, " not done");
					done = false;
					break;
				}
			}
			if (!done) { return false; }

			Genode::log("------------------- switch to I/O ----------------");
			/* arm I/O and rebrand entries */
			for (Genode::uint32_t i = 0; i < _levels; i++) {
				Entry &e = _entry[i];
				e.tag = Cbe::Tag::IO_TAG;
			}
			_io = true;

			return true;
		}

		Primitive peek_completed_primitive()
		{
			// Genode::log(__func__);

			Primitive p { };
			if (!_pending_primitive.valid()) { return p; }

			bool completed = true;
			for (Genode::uint32_t i = 0; i < _levels; i++) {
				Entry &e = _entry[i];
				if (!e.io_done) {
					completed = false;
					break;
				}
			}

			if (completed) {
				p = _pending_primitive;
				p.success = Cbe::Primitive::Success::TRUE;
			}

			return p;
		}

		Cbe::Physical_block_address peek_completed_root(Cbe::Primitive const &p) const
		{
			Genode::log(__func__, "p: ", p.block_number);

			Entry const &e = _entry[_levels-1];
			return e.new_pba;
		}

		void peek_competed_root_hash(Cbe::Primitive const &p, Cbe::Hash &hash) const
		{
			Genode::log(__func__, "p: ", p.block_number);

			Entry const &e = _entry[_levels-1];
			Sha256_4k::Data const *data = reinterpret_cast<Sha256_4k::Data const*>(&e.data);
			Sha256_4k::Hash &h = *reinterpret_cast<Sha256_4k::Hash*>(&hash);
			Sha256_4k::hash(*data, h);
		}

		void drop_completed_primitive(Cbe::Primitive const &p)
		{
			Genode::log(__func__, " p: ", p.block_number);

			if (p.block_number == _pending_primitive.block_number) {
				_pending_primitive = Cbe::Primitive { };
				return;
			}

			Genode::error(__func__, ": invalid primitive");
			throw -1;
		}

		Primitive peek_generated_primitive()
		{
			// Genode::log(__func__);

			Primitive p { };
			for (Genode::uint32_t i = 0; i < _levels; i++) {
				Entry &e = _entry[i];
				if (e.in_progress || e.done) { continue; }

				bool const cache = e.tag == Cbe::Tag::CACHE_TAG;
				Cbe::Primitive::Number const block_number = cache ? e.old_pba : e.new_pba;
				p = Primitive {
					.tag          = e.tag,
					.operation    = Cbe::Primitive::Operation::WRITE,
					.success      = Cbe::Primitive::Success::FALSE,
					.block_number = block_number,
					.index        = 0,
				};
				break;
			}
			return p;
		}

		Cbe::Block_data &peek_generated_data(Cbe::Primitive const &p)
		{
			Genode::log(__func__, " p: ", p.block_number);

			for (Genode::uint32_t i = 0; i < _levels; i++) {
				Entry &e = _entry[i];
				bool const cache = e.tag == Cbe::Tag::CACHE_TAG;
				bool const match = p.block_number == (cache ? e.old_pba : e.new_pba);
				if (match) { return e.data; }
			}

			Genode::error(__func__, ": invalid primitive");
			throw -1;
		}

		void drop_generated_primitive(Cbe::Primitive const &p)
		{
			Genode::log(__func__, " p: ", p.block_number);

			for (Genode::uint32_t i = 0; i < _levels; i++) {
				Entry &e = _entry[i];
				bool const cache = e.tag == Cbe::Tag::CACHE_TAG;
				bool const match = p.block_number == (cache ? e.old_pba : e.new_pba);
				if (!match) { continue; }
				
				e.in_progress = true;
				return;
			}

			Genode::error(__func__, ": invalid primitive");
			throw -1;
		}

		void mark_completed_crypto_primitive(Cbe::Primitive const &p)
		{
			Genode::log(__func__, " p: ", p.block_number);

			for (Genode::uint32_t i = 0; i < _levels; i++) {
				Entry &e = _entry[i];
				bool const crypto = e.tag == Cbe::Tag::CRYPTO_TAG_ENCRYPT;
				bool const match = p.block_number == e.new_pba;
				if (!crypto || !match) { continue; }

				e.done = true;
				return;
			}

			Genode::error(__func__, ": invalid primitive");
			throw -1;
		}

		Primitive peek_generated_io_primitive()
		{
			// Genode::log(__func__);

			Primitive p { };

			if (!_io) { return p; }

			for (Genode::uint32_t i = 0; i < _levels; i++) {
				Entry &e = _entry[i];

				if (e.io_in_progress || !e.done) { continue; }

				p = Primitive {
					.tag          = Cbe::Tag::IO_TAG,
					.operation    = Cbe::Primitive::Operation::WRITE,
					.success      = Cbe::Primitive::Success::FALSE,
					.block_number = e.new_pba,
					.index        = 0,
				};
				break;
			}
			return p;
		}

		Cbe::Block_data &peek_generated_io_data(Cbe::Primitive const &p)
		{
			Genode::log(__func__, " p: ", p.block_number);

			for (Genode::uint32_t i = 0; i < _levels; i++) {
				Entry &e = _entry[i];
				bool const match = p.block_number == e.new_pba;
				if (match) { return e.data; }
			}

			Genode::error(__func__, ": invalid primitive");
			throw -1;
		}

		void drop_generated_io_primitive(Cbe::Primitive const &p)
		{
			Genode::log(__func__, " p: ", p.block_number);

			for (Genode::uint32_t i = 0; i < _levels; i++) {
				Entry &e = _entry[i];
				bool const io = e.tag == Cbe::Tag::IO_TAG;
				bool const match = p.block_number == e.new_pba;
				if (!io || !match) { continue; }
				
				e.io_in_progress = true;
				return;
			}

			Genode::error(__func__, ": invalid primitive");
			throw -1;
		}

		void mark_completed_io_primitive(Cbe::Primitive const &p)
		{
			Genode::log(__func__, " p: ", p.block_number);

			for (Genode::uint32_t i = 0; i < _levels; i++) {
				Entry &e = _entry[i];
				bool const io = e.tag == Cbe::Tag::IO_TAG;
				bool const match = p.block_number == e.new_pba;
				if (!io || !match) { continue; }

				e.io_done = true;
				return;
			}

			Genode::error(__func__, ": invalid primitive");
			throw -1;
		}
};

#endif /* _CBE_WRITE_BACK_MODULE_H_ */
