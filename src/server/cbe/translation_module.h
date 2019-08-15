/*
 * Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
 *
 * This file is part of the Consistent Block Encrypter project, which is
 * distributed under the terms of the GNU Affero General Public License
 * version 3.
 */

#ifndef _CBE_TRANSLATION_MODULE_H_
#define _CBE_TRANSLATION_MODULE_H_

/* repo includes */
#include <util/sha256_4k.h>

/* local includes */
#include <cbe/types.h>


namespace Cbe { namespace Module {

	enum { TRANSLATION_MAX_LEVELS = 6, };

	struct Translation_Data
	{
		Cbe::Block_data item[1];
	} __attribute__((packed));

	class Translation;

} /* namespace Module */ } /* namespace Cbe */


class Cbe::Module::Translation
{
	public:

		static constexpr uint32_t MAX_LEVELS = TRANSLATION_MAX_LEVELS;

	private:

		Cbe::Type_i_node const &_get_node(Cbe::Block_data const &data, uint32_t i) const
		{
			using T1 = Cbe::Type_i_node;
			T1 const *entry = reinterpret_cast<T1 const*>(&data);
			return entry[i];
		}

		struct Data
		{
			uint32_t _avail { 0u };

			bool available(uint32_t level) const { return _avail & (1u << (level-1)); }
			void set_available(uint32_t level) { _avail |= (1u << (level-1)); }

			void reset() { _avail = 0u; }
		};

		Cbe::Type_1_node_info _walk[MAX_LEVELS] { };

		Data _data { };

		Cbe::Primitive  _current    { };
		uint32_t        _level      { ~0u };
		Cbe::Physical_block_address _next_pba { Cbe::INVALID_PBA };

		Cbe::Physical_block_address _data_pba { Cbe::INVALID_PBA };

		bool _suspended { false };

		bool _free_tree { false };

		Cbe::Tree_helper &_tree_helper;

	public:

		Translation(Cbe::Tree_helper &helper, bool free_tree)
		: _free_tree(free_tree), _tree_helper(helper)
		{ }

		/**
		 * Return height of the tree
		 *
		 * \return height of the tree
		 */
		uint32_t height() const { return _tree_helper.height(); }

		/**
		 * Return index for address of given level
		 *
		 * \return index
		 */
		uint32_t index(Cbe::Virtual_block_address const vba,
		               uint32_t                   const level)
		{
			return _tree_helper.index(vba, level);
		}

		/**
		 * Check if the pool can accept a new request
		 *
		 * \return true if the request can be accepted, otherwise false
		 */
		bool acceptable() const
		{
			return !_current.valid() && !_suspended;
		}


		void suspend()
		{
			_suspended = true;
		}

		void resume()
		{
			_suspended = false;
		}

		/**
		 * Submit a new translation request
		 *
		 * \param r  physical block address of the root of the tree
		 * \param p  referencet to the primitive
		 */
		void submit_primitive(Cbe::Physical_block_address r,
		                      Cbe::Generation root_gen,
		                      Cbe::Hash const &root_hash,
		                      Cbe::Primitive const &p)
		{
			if (_current.valid()) { throw -1; }

			_data.reset();

			_level = _tree_helper.height();

			for (uint32_t i = 0; i < _level; i++) {
				_walk[i].pba = Cbe::INVALID_PBA;
			}

			_walk[_level].pba = r;
			_walk[_level].gen = root_gen;
			Genode::memcpy(_walk[_level].hash.values, root_hash.values, sizeof (Cbe::Hash));

			_current   = p;
			_data_pba  = Cbe::INVALID_PBA;
			_next_pba  = _walk[_level].pba;
		}

		bool execute(Translation_Data &trans_data)
		{
			/* no active translation request */
			if (!_current.valid()) { return false; }

			/* request already translated */
			if (_data_pba != Cbe::INVALID_PBA) { return false; }

			if (!_data.available(_level)) {

				/* data request already pending */
				if (_next_pba != Cbe::INVALID_PBA) { return false; }

				/* or use previous level data to get next level */
				uint32_t const i = _tree_helper.index(_current.block_number, _level+1);
				Cbe::Type_i_node const &n = _get_node(trans_data.item[0], i);

				_walk[_level].pba = n.pba;
				_walk[_level].gen = n.gen;

				Genode::memcpy(_walk[_level].hash.values, n.hash.values,
				               sizeof (Cbe::Hash));

				_next_pba = _walk[_level].pba;
				return true;
			}

			/*
			 * Check hash
			 */
			struct Hash_mismatch { };
			Sha256_4k::Hash hash { };
			Sha256_4k::Data const &data =
				*reinterpret_cast<Sha256_4k::Data const*>(&trans_data.item[0]);
			Sha256_4k::hash(data, hash);

			Cbe::Hash const &h = _walk[_level].hash;

			if (Genode::memcmp(hash.values, h.values, sizeof (Cbe::Hash))) {
				Genode::error("level: ", _level, " pba: ", _walk[_level].pba, " <", hash, "> != <", h, ">");
				for (uint32_t l = 0; l < _tree_helper.height()+1; l++) {
					Genode::error("node[", l, "]: ", _walk[l].pba, " <", _walk[l].hash, ">");
				}
				throw Hash_mismatch();
			}

			/*
			 * We query the next level and should it already be the last,
			 * we have found the pba for the data node.
			 *
			 * For the VBD we are interested in the pba of the leaf
			 * but for the FT we look for the pba of the type 2 node.
			 */
			uint32_t const data_level = _free_tree ? 1 : 0;
			if (--_level == data_level) {
				uint32_t const parent_level = data_level + 1;
				uint32_t const i = _tree_helper.index(_current.block_number, parent_level);
				Cbe::Type_i_node const &n = _get_node(trans_data.item[0], i);

				_walk[_level].pba = n.pba;
				_walk[_level].gen = n.gen;
				Genode::memcpy(_walk[_level].hash.values, n.hash.values,
				               sizeof (Cbe::Hash));

				_data_pba = _walk[_level].pba;
			}

			return true;
		}

		/**
		 *
		 */
		Cbe::Primitive peek_completed_primitive()
		{
			if (_data_pba != Cbe::INVALID_PBA) {
				return Cbe::Primitive {
					.tag          = _current.tag,
					.operation    = _current.operation,
					.success      = Cbe::Primitive::Success::FALSE,
					.block_number = _data_pba,
					.index        = _current.index,
				};
			}

			return Cbe::Primitive { };
		}

		/**
		 *
		 */
		void drop_completed_primitive(Cbe::Primitive const &p)
		{
			if (p.block_number != _data_pba) {
				Genode::error(__func__, " invalid primitive");
				throw -1;
			}

			/* allow further translation requests */
			_current = Cbe::Primitive { };

			/* reset completed primitive */
			_data_pba = Cbe::INVALID_PBA;
		}

		/**
		 * 
		 */
		Cbe::Primitive::Number get_virtual_block_address(Cbe::Primitive const &p)
		{
			if (p.block_number != _data_pba) { throw -2; }

			return _current.block_number;
		}

		bool get_physical_block_addresses(Cbe::Primitive const &p,
		                                  Cbe::Physical_block_address *pba, size_t n)
		{
			if (_data_pba == Cbe::INVALID_PBA
			    || p.block_number != _data_pba
			    || !pba
			    || n > MAX_LEVELS) { return false; }

			for (uint32_t l = 0; l < _tree_helper.height()+1; l++) {
				pba[l] = _walk[l].pba;
			}

			return true;
		}

		bool get_type_1_info(Cbe::Primitive const &p,
		                     Cbe::Type_1_node_info *info, size_t n)
		{
			if (_data_pba == Cbe::INVALID_PBA
			    || p.block_number != _data_pba
			    || !info
			    || n > MAX_LEVELS) { return false; }

			for (uint32_t l = 0; l < _tree_helper.height()+1; l++) {
				MDBG(TRANS, __func__, ":", __LINE__, " _walk[", l, "]: ", _walk[l].pba);
				info[l] = _walk[l];
			}

			return true;
		}

		void dump() const
		{
			Cbe::Virtual_block_address const vba = _current.block_number;
			Genode::error("WALK: vba: ", vba);
			for (uint32_t l = 0; l < _tree_helper.height()+1; l++) {
				Genode::error("      ", _walk[_tree_helper.height()-l].pba, " <", _walk[_tree_helper.height()-l].hash, ">");
			}
		}

		/**
		 * Check for any generated primitive
		 *
		 * \return true if I/O primtive is pending, false otherwise
		 */
		Cbe::Primitive peek_generated_primitive() const
		{
			if (_next_pba != Cbe::INVALID_PBA) {
				return Cbe::Primitive {
					.tag          = Tag::TRANSLATION_TAG,
					.operation    = Cbe::Primitive::Operation::READ,
					.success      = Cbe::Primitive::Success::FALSE,
					.block_number = _next_pba,
					.index        = 0,
				};
			}

			return Cbe::Primitive { };
		}

		/**
		 * Discard generated primitive
		 *
		 * \param p   reference to the primitive being discarded
		 */
		void discard_generated_primitive(Cbe::Primitive const &p)
		{
			if (p.block_number != _next_pba) {
				Genode::error(__func__, " invalid primitive");
				throw -1;
			}

			_next_pba = Cbe::INVALID_PBA;
		}

		/**
		 * Mark the primitive as completed
		 *
		 * \param p  reference to Primitive that is used to mark
		 *           the corresponding internal primitive as completed
		 */
		void mark_generated_primitive_complete(Cbe::Primitive const  &p,
		                                       Cbe::Block_data const &data,
		                                       Translation_Data &trans_data)
		{
			if (p.block_number != _next_pba) {
				Genode::error(__func__, " invalid primitive");
				throw -1;
			}

			_data.set_available(_level);
			Genode::memcpy(&trans_data.item[0], &data, sizeof (Cbe::Block_data));
		}
};

#endif /* _CBE_TRANSLATION_MODULE_H_ */
