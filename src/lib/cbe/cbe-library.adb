--
-- Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
--
-- This file is part of the Consistent Block Encrypter project, which is
-- distributed under the terms of the GNU Affero General Public License
-- version 3.
--

pragma Ada_2012;

package body CBE.Library
with Spark_Mode
is
	function Discard_Snapshot (Active_Snaps : in out Snapshots_Type;
	                           Curr_Snap_ID :        Snapshot_ID_Type)
	return Boolean
	is
		Lowest_Snap_ID : Snapshot_ID_Type := Snapshot_ID_Invalid;
	begin
		for Snap of Active_Snaps loop
			if
				Snapshot_Valid (Snap) and
				not Snapshot_Keep (Snap) and
				Snap.ID /= Curr_Snap_ID and
				Snap.ID < Lowest_Snap_ID
			then
				Lowest_Snap_ID := Snap.ID;
			end if;
		end loop;

		if Lowest_Snap_ID = Snapshot_ID_Invalid then
			return False;
		end if;

		Active_Snaps (Snapshots_Index_Type (Lowest_Snap_ID)).ID :=
			Snapshot_ID_Invalid;

		-- DBG("discard snapshot: ", Snap);
		return True;
	end Discard_Snapshot;


	function Timeout_Request_Valid (Time : Timestamp_Type)
	return Timeout_Request_Type
	is (
		Valid   => True,
		Timeout => Time);


	function Timeout_Request_Invalid
	return Timeout_Request_Type
	is (
		Valid   => False,
		Timeout => 0);


--
-- Not translated as only for debugging
--
--	procedure Dump_Cur_Sb_Info () const
--	is begin
--		Cbe::Super_Block const &sb := Obj.Super_Blocks (Obj.Cur_SB);
--		Snapshot_Type    const &Snap := sb.Snapshots (Obj.Cur_SB);
--
--		Cbe::Physical_Block_Address const root_Number := Snap.PBA;
--		Cbe::Height                 const height      := Snap.Height;
--		Cbe::Number_Of_Leafs       const leafs      := Snap.Leafs;
--
--		Cbe::Degree                 const degree      := sb.Degree;
--		Cbe::Physical_Block_Address const free_Number := sb.Free_Number;
--		Cbe::Number_Of_Leafs       const free_Leafs := sb.Free_Leafs;
--		Cbe::Height                 const free_Height := sb.Free_Height;
--
--		Genode::log ("Virtual block-device info in SB (", Obj.Cur_SB, "): ",
--		            " SNAP (", Obj.Cur_SB, "): ",
--		            "tree height: ", height, " ",
--		            "edges per node: ", degree, " ",
--		            "leafs: ", leafs, " ",
--		            "root block address: ", root_Number, " ",
--		            "free block address: ", free_Number, " ",
--		            "free leafs: (", free_Leafs, "/", free_Height, ")"
--		);
--	end Dump_Cur_Sb_Info;


	function Super_Block_Snapshot_Slot (SB : Super_Block_Type)
	return Snapshot_ID_Type
	is
		Snap_Slot : Snapshot_ID_Type := Snapshot_ID_Invalid_Slot;
	begin
		For_Snapshots:
		for Snap_Index in Snapshots_Index_Type loop
			if
				Snapshot_Valid (SB.Snapshots (Snap_Index)) and
				SB.Snapshots (Snap_Index).ID = SB.Snapshot_ID
			then
				Snap_Slot := Snapshot_ID_Type (Snap_Index);
				exit For_Snapshots;
			end if;
		end loop For_Snapshots;
		return Snap_Slot;
	end Super_Block_Snapshot_Slot;


	procedure Initialize_Object (
		Obj     : out Object_Type;
		Now     :     Timestamp_Type;
		Sync    :     Timestamp_Type;
		Secure  :     Timestamp_Type;
		SBs     :     Super_Blocks_Type;
		Curr_SB :     Super_Blocks_Index_Type)
	is
		Snap_Slot : constant Snapshot_ID_Type :=
			Super_Block_Snapshot_Slot (SBs (Curr_SB));

		Degree : constant Tree_Degree_Type          := SBs (Curr_SB).Degree;
		Height : constant Tree_Level_Type           := SBs (Curr_SB).Snapshots (Snapshots_Index_Type (Snap_Slot)).Height;
		Leafs  : constant Tree_Number_Of_Leafs_Type := SBs (Curr_SB).Snapshots (Snapshots_Index_Type (Snap_Slot)).Nr_Of_Leafs;
	begin

--
-- Not translated as object size must be checked only for the Library
-- Module itself from now on.
--
--		--
--		-- We have to make sure we actually execute the code to check
--		-- if we provide enough space for the SPARK objects.
--		--
--		if not _Object_Sizes_Match then
--			-- Genode::error ("object size mismatch");
--			raise program_error; -- throw Spark_Object_Size_Mismatch;
--		end if;

--
-- Not translated as it is done already during Obj assignment
--
--		--
--		-- Copy initial state of all super-blocks. During the life-time
--		-- of the CBE library these blocks will only be (over-)written
--		-- and nevert read again.
--		--
--		--
--		-- (The idea is to keep the setup phase seperated from the actual
--		--  CBE work during run-time - not sure if this is necessary.)
--		--
--		for uint32_T i := 0; i < Cbe::NUM_SUPER_BLOCKS; i++ loop
--			Genode::memcpy (&Obj.Super_Blocks (i), &Sbs (i), sizeof (Cbe::Super_Block));
--		end loop;

--
-- Not translated as already done in the declarative part of the procedure
--
--		--
--		-- Now we look up the proper snapshot from theCurr super-block
--		-- and fill in our internal meta-data.
--		--
--
--		Obj.Cur_SB =Curr_SB;
--
--		using SB := Cbe::Super_Block;
--		using SS := Cbe::Snapshot;
--
--		SB const &sb := Obj.Super_Blocks (Obj.Cur_SB);
--		uint32_T snap_Slot := sb.Snapshot_Slot ();

		if Snap_Slot = Snapshot_ID_Invalid_Slot then
			-- Genode::error ("snapshot slot not found");
			raise program_error; -- throw Invalid_Snapshot_Slot;
		end if;

--
-- Not translated as already done in the declarative part of the procedure
--
--		Obj.Cur_SB := snap_Slot;
--
--		SS const &Snap := sb.Snapshots (Obj.Cur_SB);
--
--		Cbe::Degree           const degree := sb.Degree;
--		Cbe::Height           const height := Snap.Height;
--		Cbe::Number_Of_Leafs const leafs := Snap.Leafs;

		--
		-- The Current implementation is limited with regard to the
		-- tree topology. Make sure it fits.
		--
		if Height > Tree_Max_Height or Height < Tree_Min_Height then
			-- Genode::error ("tree height of ", height, " not supported");
			raise program_error; -- throw Invalid_Tree;
		end if;

		if Degree < Tree_Min_Degree then
			-- Genode::error ("tree outer-degree of ", degree, " not supported");
			raise program_error; -- throw Invalid_Tree;
		end if;

--
-- Not translated as already done during Obj assignment
--
--		--
--		-- The VBD class isCurrly nothing more than a glorified
--		-- Translation meta-module - pass on all information that is
--		-- needed to construct the Tree_Helper.
--		--
--		--
--		-- (Having the VBD is somewhat artificial, using the Translation
--		--  module directly works well. The idea was to later on move
--		--  all module which are needed to deal with a r/o snapshort in
--		--  there and have an extended versions that is also able to
--		--  manage theCurr active working snapshot.)
--		--
--		_VBD.Construct (height, degree, leafs);
--
--		Cbe::Physical_Block_Address const free_Number := sb.Free_Number;
--		Cbe::Generation             const free_Gen    := sb.Free_Gen;
--		Cbe::Hash                   const free_Hash   := sb.Free_Hash;
--		Cbe::Height                 const free_Height := sb.Free_Height;
--		Cbe::Degree                 const free_Degree := sb.Free_Degree;
--		Cbe::Number_Of_Leafs       const free_Leafs  := sb.Free_Leafs;
--
--		--
--		-- The FT encapsulates all modules needed for traversing the
--		-- free-tree and allocating new blocks. For now we do not update
--		-- the FT itself, i.E, only the leaf node entries are changed.
--		--
--		--
--		-- (Later, when the FT itself is updating its inner-nodes in a CoW
--		--  fashion, we will store the root and Hash for a given generation.
--		--  That means every super-block will probably have its own FT.
--		--  After all the FT includes all nodes used by the list of active
--		--  snapshots.)
--		--
--		_Free_Tree.Construct (free_Number, free_Gen, free_Hash, free_Height,
--		                     free_Degree, free_Leafs);
--
--		--
--		-- The Current version always is the last secured version incremented
--		-- by one.
--		--
--		_Last_Secured_Generation := sb.Last_Secured_Generation;
--		_Cur_Gen                 := _Last_Secured_Generation + 1;
--		_Last_Snapshot_ID        := Snap.ID;
--
--		--
--		-- If the timeout intervals were configured set initial timeout.
--		--
--		-- (It stands to reasons if we should initial or rather only set
--		--  them when a write Request was submitted.)
--		if _sync_interval   then _sync_timeout_request = { true, _sync_interval }; end if;
--		if _secure_interval then _secure_timeout_request = { true, _secure_interval }; end if;

		Obj := (
			Sync_Interval           => Sync,
			Last_Time               => Now,
			Secure_Interval         => Secure,
			Last_Secure_Time        => Now,
			Sync_Timeout_Request    => (
				if Sync /= 0 then Timeout_Request_Valid (Sync)
				else Timeout_Request_Invalid),

			Secure_Timeout_Request  => (
				if Secure /= 0 then Timeout_Request_Valid (Secure)
				else Timeout_Request_Invalid),

			Execute_Progress        => False,
			Request_Pool_Obj        => Pool.Initialized_Object,
			Splitter_Obj            => Splitter.Initialized_Object,
			Crypto_Obj              => Crypto.Initialized_Object (
				Key => (
					65, 108, 108, 32,
					121, 111, 117, 114,
					32, 98, 97, 115,
					101, 32, 97, 114,
					101, 32, 98, 101,
					108, 111, 110, 103,
					32, 116, 111, 32,
					117, 115, 32, 32)), -- "All your base are belong to us  "

			Crypto_Data             => (others => 0),
			Io_Obj                  => Block_IO.Initialized_Object,
			Io_Data                 => (others => (others => 0)),
			Cache_Obj               => Cache.Initialized_Object,
			Cache_Data              => (others => (others => 0)),
			Cache_Job_Data          => (others => (others => 0)),
			Cache_Flusher_Obj       => Cache_Flusher.Initialized_Object,
			Trans_Data              => (others => (others => 0)),
			VBD                     =>
				Virtual_Block_Device.Initialized_Object (
					Height, Degree, Leafs),

			Write_Back_Obj          => Write_Back.Initialized_Object,
			Write_Back_Data         => (others => (others => 0)),
			Sync_SB_Obj             => Sync_Superblock.Initialized_Object,
			Free_Tree_Obj           => Free_Tree.Initialized_Object (
				SBs (Curr_SB).Free_Number,
				SBs (Curr_SB).Free_Gen,
				SBs (Curr_SB).Free_Hash,
				SBs (Curr_SB).Free_Height,
				SBs (Curr_SB).Free_Degree,
				SBs (Curr_SB).Free_Leafs),

			Free_Tree_Retry_Count   => 0,
			Free_Tree_Trans_Data    => (others => (others => 0)),
			Free_Tree_Query_Data    => (others => (others => 0)),
			Super_Blocks            => SBs,
			Cur_SB                  => Superblock_Index_Type (Curr_SB),
			Cur_Gen                 => SBs (Curr_SB).Last_Secured_Generation + 1,
			Last_Secured_Generation => SBs (Curr_SB).Last_Secured_Generation,
			Cur_Snap                => Snap_Slot,
			Last_Snapshot_ID        =>
				SBs (Curr_SB).
					Snapshots (Snapshots_Index_Type (Snap_Slot)).ID,

			Seal_Generation         => False,
			Secure_Superblock       => False,
			Superblock_Dirty        => False,
			Front_End_Req_Prim      => Request_Primitive_Invalid,
			Back_End_Req_Prim       => Request_Primitive_Invalid);

--
-- Not translated as only for debugging
--
--		-- for diagnostic reasons--
--		_Dump_Cur_SB_Info ();

	end Initialize_Object;


	function Peek_Sync_Timeout_Request (Obj : Object_Type)
	return Timeout_Request_Type
	is (Obj.Sync_Timeout_Request);


	function Peek_Secure_Timeout_Request (Obj : Object_Type)
	return Timeout_Request_Type
	is (Obj.Secure_Timeout_Request);


	procedure Ack_Sync_Timeout_Request (Obj : in out Object_Type)
	is
	begin
		Obj.Sync_Timeout_Request := Timeout_Request_Invalid;
	end Ack_Sync_Timeout_Request;


	procedure Ack_Secure_Timeout_Request (Obj : in out Object_Type)
	is
	begin
		Obj.Secure_Timeout_Request := Timeout_Request_Invalid;
	end Ack_Secure_Timeout_Request;


--
-- Not translated as only for debugging
--
--	procedure Dump_Cur_SB_Info () const
--	is begin
--		_Dump_Cur_SB_Info ();
--	end Dump_Cur_SB_Info;


	function Curr_SB (Obj : Object_Type)
	return Super_Blocks_Index_Type
	is
	begin
		if Obj.Cur_SB > Superblock_Index_Type (Super_Blocks_Index_Type'Last) then
			raise program_error;
		end if;
		return Super_Blocks_Index_Type (Obj.Cur_SB);
	end Curr_SB;


	function Curr_Snap (Obj : Object_Type)
	return Snapshots_Index_Type
	is
	begin
		if Obj.Cur_Snap > Snapshot_ID_Type (Snapshots_Index_Type'Last) then
			raise program_error;
		end if;
		return Snapshots_Index_Type (Obj.Cur_Snap);
	end Curr_Snap;


	function Max_VBA (Obj : Object_Type)
	return Virtual_Block_Address_Type
	is
	begin
		return
			Virtual_Block_Address_Type (
				Obj.Super_Blocks (Curr_SB (Obj)).
					Snapshots (Curr_Snap (Obj)).Nr_Of_Leafs - 1);
	end Max_VBA;


	procedure Execute (
		Obj              : in out Object_Type;
		Now              :        Timestamp_Type)
--		Show_Progress    :        Boolean;
--		Show_If_Progress :        Boolean)
	is
		Progress : Boolean := False;
	begin

		-------------------
		-- Time handling --
		-------------------

		--
		-- Query current time and check if a timeout has triggered
		--

		--
		-- Seal the current generation if sealing is not already
		-- in Progress. In case no write operation was performed just set
		-- the trigger for the next interval.
		--
		--
		-- (Instead of checking all Cache entries it would be nice if the
		--  Cache module would provide an interface that would allow us to
		--  simple check if it contains any dirty entries as it could easily
		--  track that condition internally itself.)
		--
		if
			Now - Obj.Last_Time >= Obj.Sync_Interval and
			not Obj.Seal_Generation
		then
			Declare_Cache_Dirty:
			declare
				Cache_Dirty : Boolean := False;
			begin
				For_Cache_Data:
				for Cache_Index in Cache.Cache_Index_Type loop
					if Cache.Dirty (Obj.Cache_Obj, Cache_Index) then
						Cache_Dirty := True;
						exit For_Cache_Data;
					end if;
				end loop For_Cache_Data;

				if Cache_Dirty then
					-- Genode::log ("\033[93;44m", __Func__, " SEAL current generation: ", Obj.Cur_Gen);
					Obj.Seal_Generation := True;
				else
					-- DBG("Cache is not dirty, re-arm trigger");
					Obj.Last_Time := Now;
					Obj.Sync_Timeout_Request := Timeout_Request_Valid (Obj.Sync_Interval);
				end if;
			end Declare_Cache_Dirty;
		end if;

		--
		-- Secure the current super-block if securing is not already
		-- in Progress. In case no write operation was performed, i.E., no
		-- snapshot was changed, just set the trigger for the next interval.
		--
		--
		-- (Obj.Superblock_Dirty is set whenver the Write_Back module has done its work
		--  and will be reset when the super-block was secured.)
		--
		if
			Now - Obj.Last_Secure_Time >= Obj.Secure_Interval and
			not Obj.Secure_Superblock
		then
			if Obj.Superblock_Dirty then
				-- Genode::log ("\033[93;44m", __Func__,
				--              " SEALCurr super-block: ", Obj.Cur_SB);
				Obj.Secure_Superblock := True;
			else
				-- DBG("no snapshots created, re-arm trigger");
				Obj.Last_Secure_Time := Now;
			end if;
		end if;

		------------------------
		-- Free-tree handling --
		------------------------

		--
		-- The FT meta-module uses the Translation module internally and
		-- needs access to the Cache since it wants to use its data.
		-- Because accessing a Cache entry will update its LRU value, the
		-- Cache must be mutable (that is also the reason we need the
		-- time object).
		--
		-- Since it might need to reuse reserved blocks, we have to hand
		-- over all active snapshots as well as the last secured generation.
		-- Both are needed for doing the reuse check.
		--
		--
		-- (Rather than passing the Cache module itself to the FT it might
		--  be better to use a different interface for that purpose as I
		--  do not know how well the current solution works with SPARK...)
		--
		declare
		begin
			Free_Tree.Execute (
				Obj.Free_Tree_Obj,
				Obj.Super_Blocks (Curr_SB (Obj)).Snapshots,
				Obj.Last_Secured_Generation,
				Obj.Free_Tree_Trans_Data,
				Obj.Cache_Obj,
				Obj.Cache_Data,
				Obj.Free_Tree_Query_Data,
				Now);

			if Free_Tree.Execute_Progress (Obj.Free_Tree_Obj) then
				Progress := True;
			end if;
			-- LOG_PROGRESS(FT_Progress);
		end;

		--
		-- A complete primitive was either successful or has failed.
		--
		-- In the former case we will instruct the Write_Back module to
		-- write all changed nodes of the VBD back to the block device
		-- and eventually will leadt to ACKing the block Request.
		--
		-- In the later case we will attempt to free reserved blocks in
		-- the FT by discarding snapshots. Briefly speaking all snapshots
		-- that were not specifically marked (see FLAG_KEEP) will be
		-- discarded. A finit number of retries will be performed. If we
		-- cannot free enough blocks, the write operation is marked as
		-- failed and will result in an I/O error at the Block session.
		--
		--
		Loop_Free_Tree_Completed_Prims:
		loop
			Declare_Prim:
			declare
				Prim : constant Primitive.Object_Type :=
					Free_Tree.Peek_Completed_Primitive (Obj.Free_Tree_Obj);
			begin
				if not Primitive.Valid (Prim) then
					exit Loop_Free_Tree_Completed_Prims;
				end if;

				if Primitive.Success (Prim) = True then
					exit Loop_Free_Tree_Completed_Prims;
				end if;

				-- DBG("allocating new blocks failed: ", Obj.Free_Tree_Retry_Count);
				if Obj.Free_Tree_Retry_Count < Free_Tree_Retry_Limit then

					Declare_Curr:
					declare
						Curr : constant Snapshot_ID_Type :=
							Obj.Super_Blocks (Curr_SB (Obj)).
								Snapshots (Curr_Snap (Obj)).ID;
					begin
						if
							Discard_Snapshot (
								Obj.Super_Blocks (Curr_SB (Obj)).Snapshots,
								Curr)
						then
							Obj.Free_Tree_Retry_Count :=
								Obj.Free_Tree_Retry_Count + 1;

							--
							-- Instructing the FT to retry the allocation will
							-- lead to clearing its internal 'query branches'
							-- state and executing the previously submitted
							-- Request again.
							--
							-- (This retry attempt is a shortcut as we do not have
							--  all information available at this point to call
							--  'submit_Request' again - so we must not call
							--  'drop_Completed_Primitive' as this will clear the
							--  Request.)
							--
							Free_Tree.Retry_Allocation (Obj.Free_Tree_Obj);

						end if;
					end Declare_Curr;
					exit Loop_Free_Tree_Completed_Prims;
				end if;

				-- Genode::error ("could not find enough useable blocks");
				Pool.Mark_Completed_Primitive (Obj.Request_Pool_Obj, Prim);
				-- DBG("-----------------------> current primitive: ", current_Primitive, " FINISHED");
				-- current_Primitive :=  : Primitive.Object_Type{ };
				-- FIXME
				Virtual_Block_Device.Trans_Resume_Translation (Obj.VBD);
				Free_Tree.Drop_Completed_Primitive (Obj.Free_Tree_Obj, Prim);

			end Declare_Prim;
			Progress := True;

		end loop Loop_Free_Tree_Completed_Prims;

-------------------------------------------------------------------------------
--		--
--		-- There are two types of generated primitives by FT module,
--		-- the traversing of the tree is done by the internal Translation
--		-- module, which will access the nodes through the Cache - I/O
--		-- primitives will therefor be generated as a side-effect of the
--		-- querying attempt by the Cache module.
--		--
--		-- - IO_TAG primitives are only used for querying type 2 nodes, i.E.,
--		--   inner nodes of the free-tree containg free or reserved blocks.
--		--
--		-- - WRITE_BACK_TAG primitve are only used for writing one changed
--		--   branch back to the block device. Having the branch written
--		--   will lead to a complete primitve.
--		--
--		loop
--
--			Prim : Primitive.Object_Type := Free_Tree.Peek_Generated_Primitive (Obj.Free_Tree_Obj);
--			if not Primitive.Valid (Prim) then
--				exit;
--			end if;
--			if not Obj.Io.Primitive_Acceptable () then
--				exit;
--			end if;
--
--			constant Index idx := Free_Tree.Peek_Generated_Data_Index (Obj.Free_Tree_Obj, Prim);
--
--			Cbe::Block_Data *data := nullptr;
--			Cbe::Tag tag { Tag_Invalid_Tag };
--			switch (Prim.Tag) {
--			case Tag_Write_Back_Tag:
--				tag  := Tag_Free_Tree_Tag_Wb;
--				--
--				-- FIXME Accessing the Cache in this way could be dangerous because
--				-- the Cache is shared by the VBD as well as the FT. If we would
--				-- not suspend the VBD while doing the write-back, another Request
--				-- could evict the entry belonging to the idx value and replace it.
--				--
--				-- (Since the Prim contains the PBA we could check the validity of
--				--  the index beforehand - but not storing the index in the first
--				--  place would be the preferable solution.)
--				--
--				data := &_Cache_Data.Item (idx.Value);
--				exit;
--			case Tag_Io_Tag:
--				tag  := Tag_Free_Tree_Tag_Io;
--				data := &_Free_Tree_Query_Data.Item (idx.Value);
--				exit;
--			default: exit;
--			}
--
--			Obj.Io.Submit_Primitive (tag, Prim, Obj.Io_Data, *data, True);
--
--			Obj.Free_Tree_Obj->drop_Generated_Primitive (Prim);
--			Progress |= True;
--		end loop;
--
--		-------------------------------
--		-- Put Request into splitter --
--		-------------------------------
--
--		--
--		-- An arbitrary sized Block Request will be cut into 4096 byte
--		-- sized primitves by the Splitter module.
--		--
--		loop
--
--			Request.constant Object_Type &req := Obj.Pool.Peek_Pending_Request ();
--			if not req.Valid () then
--				exit;
--			end if;
--			if not Obj.Splitter.Request_Acceptable () then
--				exit;
--			end if;
--
--			Obj.Pool.Drop_Pending_Request (req);
--			Obj.Splitter.Submit_Request (req);
--
--			Progress |= True;
--		end loop;
--
--		--
--		-- Give primitive to the translation module
--		--
--		loop
--
--			Prim : Primitive.Object_Type := Obj.Splitter.Peek_Generated_Primitive ();
--			if not Primitive.Valid (Prim) then
--				exit;
--			end if;
--			if not Obj.VBD->primitive_Acceptable () then
--				exit;
--			end if;
--
--			-- FIXME why is Obj.Seal_Generation check not necessary?
--			-- that mainly is intended to block write primitives--
--			if Obj.Secure_Superblock then
--				-- DBG("prevent processing new primitives while securing super-block");
--				exit;
--			end if;
--
--			Obj.Splitter.Drop_Generated_Primitive (Prim);
--
--			-- current_Primitive := Prim;
--
--			--
--			-- For every new Request, we have to use theCurrly active
--			-- snapshot as a previous Request may have changed the tree.
--			--
--			constant Cbe::Super_Block &SB := Obj.Super_Blocks (Curr_SB (Obj));
--			Snapshot_Type   constant  &Snap := SB.Snapshots (Curr_Snap (Obj));
--
--			constant Physical_Block_Address_Type  PBA  := Snap.PBA;
--			Cbe::Hash                  constant  &Hash := Snap.Hash;
--			Cbe::Generation            constant   gen  := Snap.Gen;
--
--			Obj.VBD->submit_Primitive (PBA, gen, Hash, Prim);
--			Progress |= True;
--		end loop;
--
--		-- if current_Primitive.Valid () then
--		-- 	DBG("-----------------------> current primitive: ", current_Primitive);
--		-- end if;
--
--		------------------
--		-- VBD handling --
--		------------------
--
--		--
--		-- The VBD meta-module uses the Translation module internally and
--		-- needs access to the Cache since it wants to use its data.
--		-- Because accessing a Cache entry will update its LRU value, the
--		-- Cache must be mutable (that is also the reason we need the
--		-- time object).
--		--
--		--
--		-- (Basically the same issue regarding SPARK as the FT module...)
--		--
--		{
--			VBD.Execute (Obj.VBD_Obj, Obj.Trans_Data, Obj.Cache, Obj.Cache_Data, Now);
--			constant Boolean vbd_Progress := Obj.VBD->execute_Progress ();
--			Progress |= vbd_Progress;
--			-- LOG_PROGRESS(vbd_Progress);
--		}
--
--		----------------------------
--		-- Cache_Flusher handling --
--		----------------------------
--
--		--
--		-- The Cache_Flusher module is used to flush all dirty Cache entries
--		-- to the block device and mark them as clean again. While the flusher
--		-- is doing its work, all Cache entries should be locked, i.E., do not
--		-- Cache an entry while its flushed - otherwise the change might not
--		-- end up on the block device. Should be guarded by 'Obj.Seal_Generation'.
--		--
--		-- (For better or worse it is just a glorified I/O manager. At some
--		--  point it should be better merged into the Cache module later on.)
--		--
--
--		--
--		-- Mark the corresponding Cache entry as clean. If it was
--		-- evicted in the meantime it will be ignored.
--		--
--		loop
--
--			Prim : Primitive.Object_Type := Cache_Flusher.Peek_Completed_Primitive (Obj.Cache_Flusher_Obj);
--			if not Primitive.Valid (Prim) then
--				exit;
--			end if;
--
--			if Primitive.Success (Prim) /= Request.True then
--				-- DBG(Prim);
--				raise program_Error; -- throw Primitive_Failed;
--			end if;
--
--			constant Physical_Block_Address_Type PBA := Prim.Block_Number;
--			Cache.Mark_Clean (Obj.Cache_Obj, PBA);
--			-- DBG("mark_Clean: ", PBA);
--
--			Obj.Cache_Flusher.Drop_Completed_Primitive (Prim);
--			Progress |= True;
--		end loop;
--
--		--
--		-- Just pass the primitive on to the I/O module.
--		--
--		loop
--
--			Prim : Primitive.Object_Type := Obj.Cache_Flusher.Peek_Generated_Primitive ();
--			if not Primitive.Valid (Prim) then exit; end if;
--			if not Obj.Io.Primitive_Acceptable () then exit; end if;
--
--			Cache_Index    constant   idx  := Obj.Cache_Flusher.Peek_Generated_Data_Index (Prim);
--			Cbe::Block_Data       &data := Obj.Cache_Data.Item (idx.Value);
--
--			Obj.Io.Submit_Primitive (Tag_Cache_Flush_Tag, Prim, Obj.Io_Data, data);
--
--			Obj.Cache_Flusher.Drop_Generated_Primitive (Prim);
--			Progress |= True;
--		end loop;
--
--		-------------------------
--		-- Write-back handling --
--		-------------------------
--
--		--
--		-- The Write_Back module will store a changed branch including its leaf
--		-- node on the block device.
--		--
--		-- The way itCurrly operates is as follows:
--		--    1. (CRYPTO)   it hands the leaf data to the Crypto module for encryption
--		--    2. (IO)       it hands the encrypted leaf data to I/O module to write it
--		--                  to the block device
--		--    3. (CACHE)    starting by the lowest inner node it will update the node
--		--                  entry (PBA and Hash)
--		--    4. (COMPLETE) it returns the new root PBA and root Hash
--		--
--		-- When 'Obj.Seal_Generation' is set, it will first instruct the Cache_Flusher
--		-- module to clean the Cache. Afterwards it will store the current snapshot
--		-- and increment the 'Obj.Cur_SB' as well as '_Cur_Gen' (-> there is only one
--		-- snapshot per generation and there areCurrly only 48 snapshot slots per
--		-- super-block) and set the sync trigger.
--		--
--		-- Otherwise it will just update the root Hash in place.
--		--
--
--		loop
--
--			Prim : Primitive.Object_Type := Write_Back.Peek_Completed_Primitive (Obj.Write_Back_Obj);
--			if not Primitive.Valid (Prim) then
--				exit;
--			end if;
--
--			if Primitive.Success (Prim) /= Request.True then
--				-- DBG(Prim);
--				raise program_Error; -- throw Primitive_Failed;
--			end if;
--
--			if Obj.Seal_Generation then
--
--				-- FIXME only check flusher when the Cache is dirty
--				-- FIXME and track if flusher is already active, e.G. by adding
--				--     a 'active' function that returns True whenever is doing
--				--     its job. I fear itCurrly only works by chance
--				if not Obj.Cache_Flusher.Request_Acceptable () then
--					exit;
--				end if;
--
--				Cache_Dirty : Boolean := False;
--				for uint32_T i := 0; i < Cache.Cache_Slots (Obj.Cache_Obj); i++ loop
--					constant Cache_Index idx := Cache_Index { .Value := (uint32_T)i };
--					if Cache.Dirty (Obj.Cache_Obj, idx) then
--						Cache_Dirty |= True;
--
--						constant Physical_Block_Address_Type PBA := Cache.Flush (Obj.Cache_Obj, idx);
--						-- DBG(" i: ", idx.Value, " PBA: ", PBA, " needs flushing");
--
--						Obj.Cache_Flusher.Submit_Request (PBA, idx);
--					end if;
--				end loop;
--
--				--
--				-- In case we have to flush the Cache, wait until we have finished
--				-- doing that.
--				--
--				if Cache_Dirty then
--					-- DBG("CACHE FLUSH NEEDED: Progress: ", Progress);
--					Progress |= True;
--					exit;
--				end if;
--
--				--
--				-- Look for a new snapshot slot. If we cannot find one
--				-- we manual intervention b/c there are too many snapshots
--				-- flagged as keep
--				--
--				Cbe::Super_Block &SB := Obj.Super_Blocks (Curr_SB (Obj));
--				uint32_T next_Snap := Obj.Cur_SB;
--				for uint32_T i := 0; i < Cbe::NUM_SNAPSHOTS; i++ loop
--					next_Snap := (next_Snap + 1) % Cbe::NUM_SNAPSHOTS;
--					constant Snapshot_Type &Snap := SB.Snapshots (next_Snap);
--					if not Snapshot_Valid (Snap) then
--						exit;
--					else
--						if not (Snap.Flags & Cbe::Snapshot::FLAG_KEEP) then
--							exit;
--						end if;
--					end if;
--				end loop;
--
--				if next_Snap = Obj.Cur_SB then
--					-- Genode::error ("could not find free snapshot slot");
--					-- proper handling pending--
--					raise program_Error; -- throw Invalid_Snapshot_Slot;
--					exit;
--				end if;
--
--				--
--				-- Creating a new snapshot only involves storing its
--				-- meta-data in a new slot and afterwards setting the
--				-- seal timeout again.
--				--
--				Snapshot_Type &Snap := SB.Snapshots (next_Snap);
--
--				Snap.PBA := Write_Back.Peek_Completed_Root (Obj.Write_Back_Obj, Prim);
--				Cbe::Hash *snap_Hash := &Snap.Hash;
--				Obj.Write_Back.Peek_Competed_Root_Hash (Prim, *snap_Hash);
--
--				constant Cbe::Tree_Helper &tree := Obj.VBD->tree_Helper ();
--				Snap.Height := tree.Height ();
--				Snap.Leafs := tree.Leafs ();
--				Snap.Gen := Obj.Cur_Gen;
--				Snap.ID  := ++Obj.Last_Snapshot_ID;
--
--				-- DBG("new snapshot for generation: ", Obj.Cur_Gen, " Snap: ", Snap);
--
--				Obj.Cur_Gen++;
--				Obj.Cur_SB++;
--
--				Obj.Seal_Generation := False;
--				--
--				-- (As already briefly mentioned in the time handling section,
--				--  it would be more reasonable to only set the timeouts when
--				--  we actually perform write Request.)
--				--
--				Obj.Last_Time := Now;
--				Obj.Sync_Timeout_Request := Timeout_Request_Valid (Obj.Sync_Interval);
--			else
--
--				--
--				-- No need to create a new snapshot, just update the Hash in place
--				-- and move on.
--				--
--
--				Cbe::Super_Block &SB := Obj.Super_Blocks (Curr_SB (Obj));
--				Snapshot_Type    &Snap := SB.Snapshots (Curr_Snap (Obj));
--
--				-- update snapshot--
--				constant Physical_Block_Address_Type PBA := Write_Back.Peek_Completed_Root (Obj.Write_Back_Obj, Prim);
--				-- FIXME why do we need that again?
--				if Snap.PBA /= PBA then
--					Snap.Gen := Obj.Cur_Gen;
--					Snap.PBA := PBA;
--				end if;
--
--				Cbe::Hash *snap_Hash := &Snap.Hash;
--				Obj.Write_Back.Peek_Competed_Root_Hash (Prim, *snap_Hash);
--			end if;
--
--			--
--			-- We touched the super-block, either by updating a snapshot or by
--			-- creating a new one - make sure it gets secured within the next
--			-- interval.
--			--
--			Obj.Superblock_Dirty |= True;
--
--			Obj.Write_Back.Drop_Completed_Primitive (Prim);
--
--			--
--			-- Since the write Request is finally finished, all nodes stored
--			-- at some place "save" (leafs on the block device, inner nodes within
--			-- the Cache, acknowledge the primitive.
--			--
--			Pool.Mark_Completed_Primitive (Obj.Request_Pool_Obj, Prim);
--			-- DBG("-----------------------> current primitive: ", current_Primitive, " FINISHED");
--			-- current_Primitive :=  : Primitive.Object_Type{ };
--			Progress |= True;
--
--			--
--			-- FIXME stalling translation as long as the write-back takes places
--			--     is not a good idea
--			--
--			Obj.VBD->trans_Resume_Translation ();
--		end loop;
--
--
--		--
--		-- Give the leaf data to the Crypto module.
--		--
--		loop
--
--			Prim : Primitive.Object_Type := Obj.Write_Back.Peek_Generated_Crypto_Primitive ();
--			if not Primitive.Valid (Prim) then
--				exit;
--			end if;
--			if not Obj.Crypto.Primitive_Acceptable () then
--				exit;
--			end if;
--
--			constant Write_Back_Data_Index idx := Obj.Write_Back.Peek_Generated_Crypto_Data (Prim);
--			Cbe::Block_Data           &data := Obj.Write_Back_Data.Item (idx.Value);
--			-- the data will be copied into the Crypto module's internal buffer--
--			Obj.Crypto.Submit_Primitive (Prim, data, Obj.Crypto_Data);
--
--			Obj.Write_Back.Drop_Generated_Crypto_Primitive (Prim);
--			Progress |= True;
--		end loop;
--
--		--
--		-- Pass the encrypted leaf data to the I/O module.
--		--
--		loop
--
--			Prim : Primitive.Object_Type := Obj.Write_Back.Peek_Generated_Io_Primitive ();
--			if not Primitive.Valid (Prim) then
--				exit;
--			end if;
--			if not Obj.Io.Primitive_Acceptable () then
--				exit;
--			end if;
--
--			constant Write_Back_Data_Index idx := Obj.Write_Back.Peek_Generated_Io_Data (Prim);
--			Cbe::Block_Data           &data := Obj.Write_Back_Data.Item (idx.Value);
--			Obj.Io.Submit_Primitive (Tag_Write_Back_Tag, Prim, Obj.Io_Data, data);
--
--			Obj.Write_Back.Drop_Generated_Io_Primitive (Prim);
--			Progress |= True;
--		end loop;
--
--		--
--		-- Update the inner nodes of the tree. This is always done after the
--		-- encrypted leaf node was stored by the I/O module.
--		--
--		loop
--
--			Prim : Primitive.Object_Type := Obj.Write_Back.Peek_Generated_Cache_Primitive ();
--			-- DBG(Prim);
--			if not Primitive.Valid (Prim) then
--				exit;
--			end if;
--
--			using PBA := Physical_Block_Address_Type;
--			constant PBA PBA        := Prim.Block_Number;
--			constant PBA update_PBA := Obj.Write_Back.Peek_Generated_Cache_Update_PBA (Prim);
--
--			--
--			-- Check if the Cache contains the needed entries. In case of the
--			-- of the old node's block that is most likely. The new one, if
--			-- there is one (that happens when the inner nodes are Obj.Not_ updated
--			-- in place, might not be in the Cache - check and Request both.
--			--
--
--			Cache_Miss : Boolean := False;
--			if not Cache.Data_Available (Obj.Cache_Obj, PBA) then
--				-- DBG("Cache miss PBA: ", PBA);
--				if Cache.Request_Acceptable (Obj.Cache_Obj, PBA) then
--					Cache.Submit_Request (Obj.Cache_Obj, PBA);
--				end if;
--				Cache_Miss |= True;
--			end if;
--
--			if PBA /= update_PBA then
--				if not Cache.Data_Available (Obj.Cache_Obj, update_PBA) then
--					-- DBG("Cache miss update_PBA: ", update_PBA);
--					if Cache.Request_Acceptable (Obj.Cache_Obj, update_PBA) then
--						Cache.Submit_Request (Obj.Cache_Obj, update_PBA);
--					end if;
--					Cache_Miss |= True;
--				end if;
--			end if;
--
--			-- read the needed blocks first--
--			if Cache_Miss then
--				-- DBG("Cache_Miss");
--				exit;
--			end if;
--
--			Obj.Write_Back.Drop_Generated_Cache_Primitive (Prim);
--
--			-- DBG("Cache hot PBA: ", PBA, " update_PBA: ", update_PBA);
--
--			--
--			-- To keep it simply, always set both properly - even if
--			-- the old and new node are the same.
--			--
--			constant Cache_Index idx        := Cache.Data_Index (Obj.Cache_Obj, PBA, Now);
--			constant Cache_Index update_IDx := Cache.Data_Index (Obj.Cache_Obj, update_PBA, Now);
--
--			constant Cbe::Block_Data &data        := Obj.Cache_Data.Item (idx.Value);
--			Cbe::Block_Data       &update_Data := Obj.Cache_Data.Item (update_IDx.Value);
--
--			--
--			-- (Later on we can remove the tree_Helper here as the outer degree,
--			--  which is used to calculate the entry in the inner node from the
--			--  VBA is set at compile-time.)
--			--
--			Obj.Write_Back.Update (PBA, Obj.VBD->tree_Helper (), data, update_Data);
--			-- make the potentially new entry as dirty so it gets flushed next time--
--			Cache.Mark_Dirty (Obj.Cache_Obj, update_PBA);
--			Progress |= True;
--		end loop;
--
--		--------------------------
--		-- Super-block handling --
--		--------------------------
--
--		--
--		-- Store the current generation and snapshot id in the current
--		-- super-block before it gets secured.
--		--
--		if Obj.Secure_Superblock and Obj.Sync_SB.Request_Acceptable () then
--
--			Cbe::Super_Block &SB := Obj.Super_Blocks (Curr_SB (Obj));
--
--			SB.Last_Secured_Generation := Obj.Cur_Gen;
--			SB.Snapshot_ID             := Obj.Cur_SB;
--
--			-- DBG("secure current super-block gen: ", Obj.Cur_Gen,
--			    " Snap.ID: ", Obj.Cur_SB);
--
--			Obj.Sync_SB.Submit_Request (Obj.Cur_SB, Obj.Cur_Gen);
--		end if;
--
--		--
--		-- When the current super-block was secured, select the next one.
--		--
--		loop
--
--			Prim : Primitive.Object_Type := Sync_SB.Peek_Completed_Primitive (Obj.Sync_SB_Obj);
--			if not Primitive.Valid (Prim) then
--				exit;
--			end if;
--
--			if Primitive.Success (Prim) /= Request.True then
--				-- DBG(Prim);
--				raise program_Error; -- throw Primitive_Failed;
--			end if;
--
--			-- DBG("primitive: ", Prim);
--
--
--			Super_Blocks_Index_Type  next_SB := Super_Blocks_Index_Type {
--				.Value := (uint8_T)((Obj.Cur_SB + 1) % Cbe::NUM_SUPER_BLOCKS)
--			};
--			Cbe::Super_Block       &next    := Obj.Super_Blocks (next_SB.Value);
--			constant Cbe::Super_Block &curr    := Obj.Super_Blocks (Curr_SB (Obj));
--			Genode::memcpy (&next, &curr, sizeof (Cbe::Super_Block));
--
--			-- handle state--
--			Obj.Cur_SB                  := next_SB;
--			Obj.Last_Secured_Generation := Sync_SB.Peek_Completed_Generation (Obj.Sync_SB_Obj, Prim);
--			Obj.Superblock_Dirty        := False;
--			Obj.Secure_Superblock       := False;
--
--			Obj.Sync_SB.Drop_Completed_Primitive (Prim);
--			Progress |= True;
--
--			--
--			-- (FIXME same was with sealing the generation, it might make
--			--  sense to set the trigger only when a write operation
--			--  was performed.)
--			--
--			Obj.Last_Secure_Time := Now;
--			Obj.Secure_Timeout_Request := Timeout_Request_Valid (Obj.Secure_Interval);
--		end loop;
--
--		--
--		-- Use I/O module to write super-block to the block device.
--		--
--		loop
--
--			Prim : Primitive.Object_Type := Obj.Sync_SB.Peek_Generated_Primitive ();
--			if not Primitive.Valid (Prim) then
--				exit;
--			end if;
--			if not Obj.Io.Primitive_Acceptable () then
--				exit;
--			end if;
--
--			uint64_T  constant   id      := Obj.Sync_SB.Peek_Generated_ID (Prim);
--			Cbe::Super_Block &SB      := Obj.Super_Blocks (id);
--			Cbe::Block_Data  &sb_Data := *reinterpret_Cast<Cbe::Block_Data*>(&SB);
--
--			Obj.Io.Submit_Primitive (Tag_Sync_Sb_Tag, Prim, Obj.Io_Data, sb_Data);
--			Obj.Sync_SB.Drop_Generated_Primitive (Prim);
--			Progress |= True;
--		end loop;
--
--		---------------------
--		-- Crypto handling --
--		---------------------
--
--		--
--		-- The Crypto module has its own internal buffer, data has to be
--		-- copied in and copied out.
--		--
--
--		constant Boolean crypto_Progress := Obj.Crypto.Execute ();
--		Progress |= crypto_Progress;
--		-- LOG_PROGRESS(crypto_Progress);
--
--		--
--		-- Only writes primitives (encrypted data) are handled here,
--		-- read primitives (decrypred data) are handled in 'give_Read_Data'.
--		--
--		loop
--
--			Prim : Primitive.Object_Type := Crypto.Peek_Completed_Primitive (Obj.Crypto_Obj);
--			if not Primitive.Valid (Prim) or Primitive.Read (Prim) then
--				exit;
--			end if;
--
--			if Primitive.Success (Prim) /= Request.True then
--				-- DBG(Prim);
--				raise program_Error; -- throw Primitive_Failed;
--			end if;
--
--			constant Write_Back_Data_Index idx := Obj.Write_Back.Peek_Generated_Crypto_Data (Prim);
--			Cbe::Block_Data &data := Obj.Write_Back_Data.Item (idx.Value);
--			-- FIXME instead of copying the data just ask the crypto module for the resulting
--			--     Hash and omit further processing in case the operation failed
--			Obj.Crypto.Copy_Completed_Data (Prim, data);
--			Write_Back.Mark_Completed_Crypto_Primitive (Obj.Write_Back_Obj, Prim, data);
--
--			Obj.Crypto.Drop_Completed_Primitive (Prim);
--			Progress |= True;
--		end loop;
--
--		--
--		-- Since encryption is performed when calling 'execute' and decryption
--		-- is handled differently, all we have to do here is to drop and mark
--		-- complete.
--		--
--		loop
--
--			Prim : Primitive.Object_Type := Obj.Crypto.Peek_Generated_Primitive ();
--			if not Primitive.Valid (Prim) then
--				exit;
--			end if;
--
--			Obj.Crypto.Drop_Generated_Primitive (Prim);
--			Crypto.Mark_Completed_Primitive (Obj.Crypto_Obj, Prim);
--
--			Progress |= True;
--		end loop;
--
--		--------------------
--		-- Cache handling --
--		--------------------
--
--		--
--		-- Pass the data used by the module in by reference so that it
--		-- can be shared by the other modules. The method will internally
--		-- copy read job data into the chosen entry. In doing so it might
--		-- evict an already populated entry.
--		--
--		constant Boolean Cache_Progress := Cache.Execute (Obj.Cache_Obj, Obj.Cache_Data, Obj.Cache_Job_Data,
--		                                           Now);
--		Progress |= Cache_Progress;
--		-- LOG_PROGRESS(Cache_Progress);
--
--		--
--		-- Read data from the block device to fill the Cache.
--		--
--		-- (The Cache module has no 'peek_Completed_Primitive ()' method,
--		--  all modules using the Cache have to poll and might be try to
--		--  submit the same Request multiple times (see its acceptable
--		--  method). It makes sense to change the Cache module so that it
--		--  works the rest of modules. That would require restructing
--		--  the modules, though.)
--		--
--		loop
--
--			Prim : Primitive.Object_Type := Cache.Peek_Generated_Primitive (Obj.Cache_Obj);
--			if not Primitive.Valid (Prim) then
--				exit;
--			end if;
--			if not Obj.Io.Primitive_Acceptable () then
--				exit;
--			end if;
--
--			constant Cache_Index idx := Cache.Peek_Generated_Data_Index (Obj.Cache_Obj, Prim);
--			Cbe::Block_Data &data := Obj.Cache_Job_Data.Item (idx.Value);
--
--			Cache.Drop_Generated_Primitive (Obj.Cache_Obj, Prim);
--
--			Obj.Io.Submit_Primitive (Tag_Cache_Tag, Prim, Obj.Io_Data, data, True);
--			Progress |= True;
--		end loop;
--
--		------------------
--		-- I/O handling --
--		------------------
--
--		--
--		-- This module handles all the block backend I/O and has to
--		-- work with all most all modules. IT uses the 'Tag' field
--		-- to differentiate the modules.
--		--
--
--		loop
--
--			Prim : Primitive.Object_Type := Io.Peek_Completed_Primitive (Obj.Io_Obj);
--			if not Primitive.Valid (Prim) then
--				exit;
--			end if;
--
--			if Primitive.Success (Prim) /= Request.True then
--				-- DBG(Prim);
--				raise program_Error; -- throw Primitive_Failed;
--			end if;
--
--			Genode::uint32constant Obj.T idx := Io.Peek_Completed_Data_Index (Obj.Io_Obj, Prim);
--			Cbe::Block_Data      &data := Obj.Io_Data.Item (idx);
--
--			--
--			-- Whenever we cannot hand a successful primitive over
--			-- to the corresponding module, leave the loop but keep
--			-- the completed primitive so that it might be processed
--			-- next time.
--			--
--			mod_Progress : Boolean := True;
--			switch (Prim.Tag) {
--
--			case Tag_Crypto_Tag_Decrypt:
--				if not Obj.Crypto.Primitive_Acceptable () then
--					mod_Progress := False;
--				else
--					constant Cbe::Tag orig_Tag := Io.Peek_Completed_Tag (Obj.Io_Obj, Prim);
--
--					--
--					-- Having to override the tag is needed because of the way
--					-- the Crypto module is hooked up in the overall data flow.
--					-- Since it is the one that acknowledges the primitive to the
--					-- pool in the read case, we have to use the tag the pool
--					-- module uses.
--					--
--					Prim.Tag := orig_Tag;
--					Obj.Crypto.Submit_Primitive (Prim, data, Obj.Crypto_Data);
--				end if;
--				exit;
--
--			case Tag_Cache_Tag:
--				-- FIXME we need a proper method for getting the right Cache job
--				--     data index, for now rely on the knowledge that there is
--				--     only one item
--				Genode::memcpy (&_Cache_Job_Data.Item (0), &data, sizeof (Cbe::Block_Data));
--				Cache.Mark_Completed_Primitive (Obj.Cache_Obj, Prim);
--				exit;
--
--			case Tag_Cache_Flush_Tag:
--				Cache_Flusher.Mark_Generated_Primitive_Complete (Obj.Cache_Flusher_Obj, Prim);
--				exit;
--
--			case Tag_Write_Back_Tag:
--				Write_Back.Mark_Completed_Io_Primitive (Obj.Write_Back_Obj, Prim);
--				exit;
--
--			case Tag_Sync_Sb_Tag:
--				Sync_SB.Mark_Generated_Primitive_Complete (Obj.Sync_SB_Obj, Prim);
--				exit;
--
--			case Tag_Free_Tree_Tag_Wb:
--				Prim.Tag := Tag_Write_Back_Tag;
--				Obj.Free_Tree_Obj->mark_Generated_Primitive_Complete (Prim);
--				exit;
--
--			case Tag_Free_Tree_Tag_Io:
--				Prim.Tag := Tag_Io_Tag;
--				-- FIXME we need a proper method for getting the right query
--				--     data index, for now rely on the knowledge that there
--				--     is only one item
--				Genode::memcpy (&_Free_Tree_Query_Data.Item (0), &data, sizeof (Cbe::Block_Data));
--				Obj.Free_Tree_Obj->mark_Generated_Primitive_Complete (Prim);
--				exit;
--
--			default: exit;
--			}
--			if not mod_Progress then
--				exit;
--			end if;
--
--			Obj.Io.Drop_Completed_Primitive (Prim);
--			Progress |= True;
--		end loop;

		Obj.Execute_Progress := Progress;
	end Execute;


	function Request_Acceptable (Obj : Object_Type)
	return Boolean
	is (Pool.Request_Acceptable(Obj.Request_Pool_Obj));


	procedure Submit_Request (
		Obj : in out Object_Type;
		Req :        Request.Object_Type)
	is
	begin
		Pool.Submit_Request (
			Obj.Request_Pool_Obj,
			Req,
			Splitter.Number_Of_Primitives (Req) );
	end Submit_Request;


	function Peek_Completed_Request (Obj : Object_Type)
	return Request.Object_Type
	is (Pool.Peek_Completed_Request (Obj.Request_Pool_Obj));


	procedure Drop_Completed_Request (
		Obj : in out Object_Type;
		Req :        Request.Object_Type)
	is begin
		Pool.Drop_Completed_Request (Obj.Request_Pool_Obj, Req);
	end Drop_Completed_Request;


	procedure Need_Data (
		Obj : in out Object_Type;
		Req :    out Request.Object_Type)
	is
	begin
		if Primitive.Valid(Obj.Back_End_Req_Prim.Prim) then
			Req := Request.Invalid_Object;
			return;
		end if;

		-- I/O module--
		declare
			Prim : constant Primitive.Object_Type :=
				Block_IO.Peek_Generated_Primitive(Obj.Io_Obj);
		begin
			if Primitive.Valid(Prim) then
				Obj.Back_End_Req_Prim := (
					Req => Request.Valid_Object (
						Op     => Primitive.Operation(Prim),
						Succ   => False,
						Blk_Nr => Primitive.Block_Number(Prim),
						Off    => 0,
						Cnt    => 1,
						Tg     => Request.Tag_Type(Tag_Invalid)
					),
					Prim => Prim,
					Tag  => Tag_IO,
					In_Progress => False
				);
				Req := Obj.Back_End_Req_Prim.Req;
			else
				Req := Request.Invalid_Object;
			end if;
		end;
	end Need_Data;


	--
	-- For now there can be only one Request pending.
	--
	function Back_End_Busy_With_Other_Request (
		Obj : Object_Type;
		Req : Request.Object_Type)
	return Boolean
	is (not Request.Equal(Obj.Back_End_Req_Prim.Req, Req) or
		Obj.Back_End_Req_Prim.In_Progress or
		Obj.Back_End_Req_Prim.Tag /= Tag_IO);


	--
	-- For now there can be only one Request pending.
	--
	function Front_End_Busy_With_Other_Request (
		Obj : Object_Type;
		Req : Request.Object_Type)
	return Boolean
	is (not Request.Equal (Obj.Front_End_Req_Prim.Req, Req));

	procedure Take_Read_Data (
		Obj      : in out Object_Type;
		Req      :        Request.Object_Type;
		Progress :    out Boolean)
	is
	begin
		Progress := false;

		if Back_End_Busy_With_Other_Request (Obj, Req) then
			return;
		end if;

		Block_IO.Drop_Generated_Primitive (
			Obj.Io_Obj,
			Obj.Back_End_Req_Prim.Prim);

		Obj.Back_End_Req_Prim.In_Progress := True;
		Progress := True;
	end Take_Read_Data;


	--
	-- Return copy of Primitive with specified Success state
	--
	function Primitive_With_Success (
		Prim    : Primitive.Object_Type;
		Success : Request.Success_Type)
	return Primitive.Object_Type
	is
		(Primitive.Valid_Object (
			Op     => Primitive.Operation    (Prim),
			Succ   => Success,
			Tg     => Primitive.Tag          (Prim),
			Blk_Nr => Primitive.Block_Number (Prim),
			Idx    => Primitive.Index        (Prim)));


	procedure Ack_Read_Data (
		Obj     : in out Object_Type;
		Req     :        Request.Object_Type;
		Data    :        Block_Data_Type;
		Progess :    out Boolean)
	is
		Prim : constant Primitive.Object_Type := Obj.Back_End_Req_Prim.Prim;
	begin
		Progess := False;

		if Back_End_Busy_With_Other_Request (Obj, Req) then
			return;
		end if;

		if Request.Success(Req) then
			Obj.Io_Data(Block_IO.Peek_Completed_Data_Index(Obj.Io_Obj)) := Data;
		end if;

		Block_IO.Mark_Generated_Primitive_Complete (
			Obj.Io_Obj,
			Primitive_With_Success (Prim, Request.Success(Req))
		);

		Obj.Back_End_Req_Prim := Request_Primitive_Invalid;

		Progess := True;
	end Ack_Read_Data;


	procedure Take_Write_Data (
		Obj      : in out Object_Type;
		Req      :        Request.Object_Type;
		Data     :    out Block_Data_Type;
		Progress :    out Boolean)
	is
		Prim : constant Primitive.Object_Type := Obj.Back_End_Req_Prim.Prim;
	begin
		Progress := False;

		if Back_End_Busy_With_Other_Request (Obj, Req) then
			return;
		end if;

		Data := Obj.Io_Data(Block_IO.Peek_Generated_Data_Index(Obj.Io_Obj, Prim));

		Block_IO.Drop_Generated_Primitive(Obj.Io_Obj, Prim);

		Progress := True;
	end Take_Write_Data;


	procedure Ack_Write_Data (
		Obj      : in out Object_Type;
		Req      :        Request.Object_Type;
		Progress :    out Boolean)
	is
		Prim : constant Primitive.Object_Type := Obj.Back_End_Req_Prim.Prim;
	begin
		Progress := False;

		if Back_End_Busy_With_Other_Request (Obj, Req) then
			return;
		end if;

		Block_IO.Mark_Generated_Primitive_Complete (
			Obj.Io_Obj,
			Primitive_With_Success (Prim, Request.Success(Req))
		);

		Obj.Back_End_Req_Prim := Request_Primitive_Invalid;

		Progress := True;
	end Ack_Write_Data;


	-- FIXME move Front_End_Req_Prim allocation into execute,
	--       turn procedure into function
	procedure Have_Data (
		Obj : in out Object_Type;
		Req :    out Request.Object_Type)
	is

		procedure Assign_Front_End_Req_Prim (
			Prim : Primitive.Object_Type;
			Tag  : Tag_Type)
		is
		begin
			Obj.Front_End_Req_Prim := (
				Req         => Pool.Request_For_Tag (Obj.Request_Pool_Obj,
				                                     Primitive.Tag(Prim)),
				Prim        => Prim,
				Tag         => Tag,
				In_Progress => False
			);
		end Assign_Front_End_Req_Prim;

	begin
		Req := Request.Invalid_Object;

		if Primitive.Valid(Obj.Front_End_Req_Prim.Prim) then
			return;
		end if;

		--
		-- When it was a read Request, we need the location to
		-- where the Crypto should copy the decrypted data.
		--
		declare
			Prim : constant Primitive.Object_Type :=
				Crypto.Peek_Completed_Primitive (Obj.Crypto_Obj);
		begin
			if
				Primitive.Valid (Prim) and
				Request."=" (Primitive.Operation (Prim), Request.Read)
			then
				Assign_Front_End_Req_Prim (Prim, Tag_Crypto);
				Req := Obj.Front_End_Req_Prim.Req;
				return;
			end if;
		end;

		--
		-- When it was a read Request, we need access to the data the Crypto
		-- module should decrypt and if it was a write Request we need the location
		-- from where to read the new leaf data.
		--
		declare
			Prim : constant Primitive.Object_Type :=
				Virtual_Block_Device.Peek_Completed_Primitive (Obj.VBD);
		begin
			if Primitive.Valid (Prim) then
				Assign_Front_End_Req_Prim (Prim, Tag_VBD);
				Req := Obj.Front_End_Req_Prim.Req;
				return;
			end if;
		end;

		--
		-- The free-tree needs the data to give to the Write_Back module.
		--
		declare
			Prim : constant Primitive.Object_Type :=
				Free_Tree.Peek_Completed_Primitive (Obj.Free_Tree_Obj);
		begin
			if Primitive.Valid (Prim) and Primitive.Success (Prim) then
				Assign_Front_End_Req_Prim (Prim, Tag_Free_Tree);
				Req := Obj.Front_End_Req_Prim.Req;
				return;
			end if;
		end;
	end Have_Data;


	function Give_Data_Index (
		Obj : Object_Type;
		Req : Request.Object_Type)
	return Primitive.Index_Type
	is
	begin
		if Front_End_Busy_With_Other_Request (Obj, Req) then
			return Primitive.Invalid_Index;
		end if;

		return Primitive.Index(Obj.Front_End_Req_Prim.Prim);
	end Give_Data_Index;


	procedure Give_Read_Data (
		Obj      : in out Object_Type;
		Req      :        Request.Object_Type;
		Data     :    out Crypto.Plain_Data_Type;
		Progress :    out Boolean)
	is
		Prim : constant Primitive.Object_Type := Obj.Front_End_Req_Prim.Prim;
		Tag  : constant Tag_Type              := Obj.Front_End_Req_Prim.Tag;
	begin
		Progress := False;

		if Front_End_Busy_With_Other_Request (Obj, Req) then
			return;
		end if;

		if Tag = Tag_Crypto then

			Crypto.Copy_Decrypted_Data (Obj.Crypto_Obj, Prim, Data);
			Crypto.Drop_Completed_Primitive (Obj.Crypto_Obj, Prim);
			Pool.Mark_Completed_Primitive (Obj.Request_Pool_Obj, Prim);

			Obj.Front_End_Req_Prim := Request_Primitive_Invalid;
			Progress := True;

		elsif Tag = Tag_VBD then

			--
			-- We have to reset Front_End_Req_Prim before because in case there
			-- is current I/O pending, we have to make sure 'Have_Data' is
			-- called again.
			--
			Obj.Front_End_Req_Prim := Request_Primitive_Invalid;

			if Block_IO.Primitive_Acceptable (Obj.Io_Obj) then

				declare
					-- cast Crypto.Plain_Data_Type to Block_Data_Type
					Block_Data : Block_Data_Type with Address => Data'Address;
				begin
					Block_IO.Submit_Primitive (
						Obj     => Obj.Io_Obj,
						Tag     => Tag_Decrypt,
						Prim    => Prim,
						IO_Data => Obj.IO_Data,
						Data    => Block_Data);
				end;

				Virtual_Block_Device.Drop_Completed_Primitive (Obj.VBD);

				Progress := True;
			end if;
		end if;
	end Give_Read_Data;


	function Give_Write_Data (
		Obj     : in out Object_Type;
		Now     :        Timestamp_Type;
		Req     :        Request.Object_Type;
		Data    :        Block_Data_Type)
	return Boolean
	is
		Prim : constant Primitive.Object_Type := Obj.Front_End_Req_Prim.Prim;
	begin
		--
		-- For now there is only one Request pending.
		--
		if not Request.Equal (Obj.Front_End_Req_Prim.Req, Req) then
			return False;
		end if;

		if Obj.Front_End_Req_Prim.Tag = Tag_Free_Tree then

			if not Write_Back.Primitive_Acceptable (Obj.Write_Back_Obj) then
				return False;
			end if;

			Obj.Free_Tree_Retry_Count := 0;

			--
			-- Accessing the write-back data in this manner is still a shortcut
			-- and probably will not work with SPARK - we have to get rid of
			-- the 'Block_Data' pointer.
			--
			declare
				WB : constant Free_Tree.Write_Back_Data_Type :=
					Free_Tree.Peek_Completed_WB_Data(Obj.Free_Tree_Obj, Prim);
			begin

				Write_Back.Submit_Primitive (
					Obj.Write_Back_Obj,
					WB.Prim, WB.Gen, WB.VBA, WB.New_PBAs, WB.Old_PBAs,
					Tree_Level_Index_Type(WB.Tree_Height),
					Data, Obj.Write_Back_Data);
			end;

			Free_Tree.Drop_Completed_Primitive(Obj.Free_Tree_Obj, Prim);
--			_Frontend_Req_Prim := Req_Prim { };
-- XXX check if default constructor produces invalid object
			Obj.Front_End_Req_Prim := Request_Primitive_Invalid;
			return True;

		--
		-- The VBD module translated a write Request, writing the data
		-- now to disk involves multiple steps:
		--
		--  1. Gathering of all nodes in the branch and looking up the
		--     volatile ones (those, which belong to theCurr generation
		--     and will be updated in place).
		--  2. Allocate new blocks if needed by consulting the FT
		--  3. Updating all entries in the nodes
		--  4. Writing the branch back to the block device.
		--
		-- Those steps are handled by different modules, depending on
		-- the allocation of new blocks.
		--
		elsif Obj.Front_End_Req_Prim.Tag = Tag_VBD then

			--
			-- As usual check first we can submit new requests.
			--
			if not Free_Tree.Request_Acceptable (Obj.Free_Tree_Obj) then
				return False;
			end if;

			if not Virtual_Block_Device.Trans_Can_Get_Type_1_Info_Spark(Obj.VBD, Prim)
			then
				return False;
			end if;

			--
			-- Then (ab-)use the Translation module and its still pending
			-- Request to get all old PBAs, whose generation we then check.
			-- The order of the array items corresponds to the level within
			-- the tree.
			--
			Declare_Old_PBAs: declare

				Old_PBAs : Type_1_Node_Infos_Type := (others => Type_1_Node_Info_Invalid);

				Trans_Height : constant Tree_Level_Type :=
					Virtual_Block_Device.Tree_Height(Obj.VBD) + 1;

				-- XXX merge Super_Blocks_Index_Type and Superblock_Index_Type
				Snap : constant Snapshot_Type :=
					Obj.Super_Blocks(Super_Blocks_Index_Type(Obj.Cur_SB))
					   .Snapshots(Snapshots_Index_Type(Obj.Cur_Snap));

				--
				-- The array of new_PBA will either get populated from the Old_PBA
				-- content or from newly allocated blocks.
				-- The order of the array items corresponds to the level within
				-- the tree.
				--
				New_PBAs   : Write_Back.New_PBAs_Type := (others => 0);
				New_Blocks : Number_Of_Blocks_Type := 0;

				--
				-- This array contains all blocks that will get freed or rather
				-- marked as reserved in the FT as they are still referenced by
				-- an snapshot.
				--
				Free_PBAs   : Free_Tree.Free_PBAs_Type := (others => 0);
				Free_Blocks : Tree_Level_Index_Type := 0;

				--
				-- Get the corresponding VBA that we use to calculate the index
				-- for the edge in the node for a given level within the tree.
				--
				VBA : constant Virtual_Block_Address_Type :=
					Virtual_Block_Address_Type(Virtual_Block_Device.trans_Get_Virtual_Block_Address(Obj.VBD, prim));
			begin

				Virtual_Block_Device.trans_Get_Type_1_Info(Obj.VBD, Old_PBAs);

				--
				-- Make sure we work with the proper snapshot.
				--
				-- (This check may be removed at some point.)
				--
				if Old_PBAs(Natural(Trans_Height - 1)).PBA /= Snap.PBA then
					raise Program_Error;
				end if;

				--
				-- Here only the inner nodes, i.E. all nodes excluding root and leaf,
				-- are considered. The root node is checked afterwards as we need the
				-- information of theCurr snapshot for that.
				--
				for I in 1 .. Trans_Height - 1 loop

					--
					-- Use the old PBA to get the node's data from the cache and
					-- use it check how we have to handle the node.
					--
					declare
						PBA : constant Physical_Block_Address_Type :=
							Old_PBAs(Natural(I)).PBA;

						Idx : constant Cache.Cache_Index_Type :=
							Cache.Data_Index(Obj.Cache_Obj, PBA, Now);

						ID : constant Tree_Child_Index_Type :=
							Virtual_Block_Device.index_For_Level(Obj.VBD, VBA, I);

--						Cbe::Block_Data const &data := _Cache_Data.Item (idx.Value);
--						uint32_T const id := _VBD->index_For_Level (VBA, i);
--						Cbe::Type_I_Node const *n := reinterpret_Cast<Cbe::Type_I_Node const*>(&data);
						Node : Type_I_Node_Block_Type with Address => Obj.Cache_Data(Idx)'Address;

						Gen : constant Generation_Type := Node(Natural(ID)).Gen;
					begin
						--
						-- In case the generation of the entry is the same as theCurr
						-- generation OR if the generation is 0 (which means it was never
						-- used before) the block is volatile and we change it in place
						-- and store it directly in the new_PBA array.
						--
						if Gen = Obj.Cur_Gen or Gen = 0 then

							New_PBAs (Tree_Level_Index_Type(I - 1)) :=
								Old_PBAs (Natural(I - 1)).PBA;

						--
						-- Otherwise add the block to the free_PBA array so that the
						-- FT will reserved it and note that we need another new block.
						--
						else
							Free_PBAs (Free_Blocks) := Old_PBAs (Natural(I - 1)).PBA;
							Free_Blocks := Free_Blocks + 1;
							New_Blocks  := New_Blocks  + 1;
						end if;
					end;

				end loop;

				-- check root node--
				if Snap.Gen = Obj.Cur_Gen or Snap.Gen = 0 then
					New_PBAs (Tree_Level_Index_Type(Trans_Height - 1)) :=
						Old_PBAs (Natural(Trans_Height - 1)).PBA;
				else
					Free_PBAs (Free_Blocks) := Old_PBAs (Natural(Trans_Height - 1)).PBA;
					Free_Blocks := Free_Blocks + 1;
					New_Blocks  := New_Blocks  + 1;
				end if;

				--
				-- Since there are blocks we cannot change in place, use the
				-- FT module to allocate the blocks. As we have to reserve
				-- the blocks we implicitly will free (free_PBA items), pass
				-- on theCurr generation.
				--
				if New_Blocks > 0 then
					Free_Tree.Submit_Request (
						Obj         => Obj.Free_Tree_Obj,
						Curr_Gen    => Obj.Cur_Gen,
						Nr_of_Blks  => New_Blocks,
						New_PBAs    => New_PBAs,
						Old_PBAs    => Old_PBAs,
						Tree_Height => Trans_Height,
						Fr_PBAs     => Free_PBAs,
						Req_Prim    => Prim,
						VBA         => VBA);
				else
					--
					-- The complete branch is still part of theCurr generation,
					-- call the Write_Back module directly.
					--
					-- (We would have to check if the module can acutally accept
					--  the Request...)
					--
					Write_Back.Submit_Primitive (
						Obj      => Obj.Write_Back_Obj,
						Prim     => Prim,
						Gen      => Obj.Cur_Gen,
						VBA      => VBA,
						New_PBAs => New_PBAs,
						Old_PBAs => Old_PBAs,
						N        => Tree_Level_Index_Type(Trans_Height),
						Data     => Data,
						WB_Data  => Obj.Write_Back_Data);
				end if;

				Virtual_Block_Device.Drop_Completed_Primitive (Obj.VBD);

				Obj.Front_End_Req_Prim := Request_Primitive_Invalid;

				--
				-- Inhibit translation which effectively will suspend the
				-- Translation modules operation and will stall all other
				-- pending requests to make sure all following Request will
				-- use the newest tree.
				--
				-- (It stands to reasons whether we can remove this check
				--  if we make sure that only the requests belonging to
				--  the same branch are serialized.)
				--
				Virtual_Block_Device.Trans_Inhibit_Translation (Obj.VBD);
				return True;
			end Declare_Old_PBAs;
		end if;
		return False;
	end Give_Write_Data;

end CBE.Library;
