--
-- Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
--
-- This file is part of the Consistent Block Encrypter project, which is
-- distributed under the terms of the GNU Affero General Public License
-- version 3.
--

pragma Ada_2012;

package body CBE.Free_Tree
with Spark_Mode
is
	procedure Initialize_Object (
		Obj     : out Object_Type;
		Rt_PBA  :     Physical_Block_Address_Type;
		Rt_Gen  :     Generation_Type;
		Rt_Hash :     Hash_Type;
		Hght    :     Tree_Level_Type;
		Degr    :     Tree_Degree_Type;
		Lfs     :     Tree_Number_Of_Leafs_Type)
	is
		Tr_Helper : constant Tree_Helper.Object_Type :=
			Tree_Helper.Initialized_Object (Degr, Hght, Lfs);
	begin
		Obj := (
			Trans_Helper       => Tr_Helper,
			Trans              => Translation.Initialized_Object (Tr_Helper, True),
			Execute_Progress   => False,
			Do_Update          => False,
			Do_WB              => False,
			WB_Done            => False,
			Nr_Of_Blocks       => 0,
			Nr_Of_Found_Blocks => 0,
			Query_Branches     => (others => Query_Branch_Invalid),
			Curr_Query_Branch  => 0,
			Found_PBAs         => (others => PBA_Invalid),
			Free_PBAs          => (others => PBA_Invalid),
			Root_PBA           => Rt_PBA,
			Root_Hash          => Rt_Hash,
			Root_Gen           => Rt_Gen,
			Curr_Query_Prim    => Primitive.Invalid_Object,
			Curr_Type_2        => IO_Entry_Invalid,
			WB_IOs             => (others => IO_Entry_Invalid),
			WB_Data            => Write_Back_Data_Invalid);
	end Initialize_Object;

	procedure Retry_Allocation (Obj : in out Object_Type)
	is
	begin
		-- Print_String ("FRTR Retry_Allocation");
		-- Print_Line_Break;

		Reset_Query_Prim (Obj);
		Obj.Do_Update        := False;
		Obj.Do_WB            := False;
		Obj.WB_Done          := False;
		Obj.WB_Data.Finished := False;

	end Retry_Allocation;

	procedure Reset_Query_Prim (Obj : in out Object_Type)
	is
	begin
		Obj.Nr_Of_Found_Blocks := 0;
		Obj.Curr_Query_Prim    := Primitive.Invalid_Object;

		--
		-- Reset query branches
		--
		Obj.Curr_Query_Branch  := 0;
		For_Query_Branches:
		for Branch_ID in Obj.Query_Branches'Range loop

			--
			-- FIXME may this be replaced by Query_Branch_Invalid
			--       or at least something like Reset_Query_Branch?
			--
			Obj.Query_Branches (Branch_ID).VBA := VBA_Invalid;
			Obj.Query_Branches (Branch_ID).Nr_Of_Free_Blocks := 0;

			For_Query_Branch_PBAs:
			for PBA_ID in Obj.Query_Branches (Branch_ID).PBAs'Range loop
				Obj.Query_Branches (Branch_ID).PBAs (PBA_ID) := PBA_Invalid;
			end loop For_Query_Branch_PBAs;

		end loop For_Query_Branches;

		-- Print_String ("FRTR Reset_Query_Prim");
		-- Print_Primitive (Obj.Curr_Query_Prim);
		-- Print_Line_Break;

	end Reset_Query_Prim;

	function Request_Acceptable (Obj : Object_Type)
	return Boolean
	is (Obj.Nr_Of_Blocks = 0);

	procedure Submit_Request (
		Obj             : in out Object_Type;
		Curr_Gen        :        Generation_Type;
		Nr_of_Blks      :        Number_Of_Blocks_Type;
		New_PBAs        :        WB_Data_New_PBAs_Type;
		Old_PBAs        :        Type_1_Node_Infos_Type;
		Tree_Height     :        Tree_Level_Type;
		Fr_PBAs         :        Free_PBAs_Type;
		-- Nr_Of_Free_Blks :        Number_Of_Blocks_Type;
		Req_Prim        :        Primitive.Object_Type;
		VBA             :        Virtual_Block_Address_Type)
	is
	begin
		if Obj.Nr_Of_Blocks /= 0 then
			return;
		end if;

		Obj.Do_Update   := False;
		Obj.Do_WB       := False;
		Obj.WB_Done     := False;
		Obj.Curr_Type_2 := IO_Entry_Invalid;

		For_WB_IOs:
		for WB_IO_ID in Obj.WB_IOs'Range loop
			Obj.WB_IOs (WB_IO_ID).State := Invalid;
		end loop For_WB_IOs;

		Obj.Nr_Of_Blocks       := Nr_Of_Blks;
		Obj.Nr_Of_Found_Blocks := 0;

		-- FIXME assert sizeof (_free_pba) == sizeof (free_pba)
		Obj.Free_PBAs := Fr_PBAs;
		-- For_Free_PBAs:
		-- for Free_PBA_ID in Obj.Free_PBAs'Range loop
		-- 	if Obj.Free_PBAs (Free_PBA_ID) /= 0 then
		-- 		Print_String ("FRTR Submit_Request free[");
		-- 		Print_Word_Dec (Free_PBA_ID);
		-- 		Print_String ("]: ");
		-- 		Print_Word_Hex (Obj.Free_PBAs (Free_PBA_ID));
		-- 		Print_Line_Break;
		-- 	end if;
		-- end loop For_Free_PBAs;

		Obj.WB_Data.Finished    := False;
		Obj.WB_Data.Prim        := Req_Prim;
		Obj.WB_Data.Gen         := Curr_Gen;
		Obj.WB_Data.VBA         := VBA;
		Obj.WB_Data.Tree_Height := Tree_Height;

		-- FIXME assert sizeof (_wb_data.new_pba) == sizeof (new_pba)
		Obj.WB_Data.New_PBAs := New_PBAs;
		-- For_New_PBAs:
		-- for New_PBA_ID in Obj.New_PBAs'Range loop
		-- 	if Obj.New_PBAs (New_PBA_ID) /= 0 then
		-- 		Print_String ("FRTR Submit_Request free[");
		-- 		Print_Word_Dec (New_PBA_ID);
		-- 		Print_String ("]: ");
		-- 		Print_Word_Hex (Obj.WB_Data.New_PBAs (New_PBA_ID));
		-- 		Print_Line_Break;
		-- 	end if;
		-- end loop For_Free_PBAs;

		-- FIXME assert sizeof (_wb_data.old_pba) == sizeof (old_pba)
		Obj.WB_Data.Old_PBAs := Old_PBAs;
		-- For_Old_PBAs:
		-- for Old_PBA_ID in Obj.Old_PBAs'Range loop
		-- 	if Obj.Old_PBAs (Old_PBA_ID).PBA /= 0 then
		-- 		Print_String ("FRTR Submit_Request free[");
		-- 		Print_Word_Dec (Old_PBA_ID);
		-- 		Print_String ("]: ");
		-- 		Print_Word_Hex (Obj.WB_Data.Old_PBAs (Old_PBA_ID).PBA);
		-- 		Print_Line_Break;
		-- 	end if;
		-- end loop For_Free_PBAs;

		Reset_Query_Prim (Obj);

	end Submit_Request;

--	function Leaf_Usable (
--		Obj              : Object_Type;
--		Active_Snaps     : Snapshots_Type;
--		Last_Secured_Gen : Generation_Type;
--		Node             : Type_II_Node_Type)
--	is
--	begin
--	end Leaf_Usable;

--	bool _leaf_useable(Cbe::Snapshot     const active[Cbe::NUM_SNAPSHOTS],
--	                   Cbe::Generation   const last_secured,
--	                   Cbe::Type_ii_node const &node) const
--	{
--		// XXX check could be done outside
--		if (!node.reserved) { return true; }
--
--		Cbe::Generation const f_gen = node.free_gen;
--		Cbe::Generation const a_gen = node.alloc_gen;
--		Cbe::Generation const s_gen = last_secured;
--
--		bool free = false;
--		/*
--		 * If the node was freed before the last secured generation,
--		 * check if there is a active snapshot that might be using the node,
--		 * i.e., its generation is after the allocation generation and before
--		 * the free generation.
--		 */
--		if (f_gen <= s_gen) {
--
--			bool in_use = false;
--			for (uint64_t i = 0; i < Cbe::NUM_SNAPSHOTS; i++) {
--				Cbe::Snapshot const &b = active[i];
--				if (!b.valid()) { continue; }
--
--				// MOD_DBG("snap: ", b);
--				Cbe::Generation const b_gen = b.gen;
--
--				bool const is_free = (f_gen <= b_gen || a_gen >= (b_gen + 1));
--
--				in_use |= !is_free;
--				if (in_use) { break; }
--			}
--
--			free = !in_use;
--		}
--		// MOD_DBG(free ? "REUSE" : " RESERVE", " PBA: ", node.pba,
--		//         " f: ", f_gen, " a: ", a_gen);
--		return free;
--	}

end CBE.Free_Tree;
