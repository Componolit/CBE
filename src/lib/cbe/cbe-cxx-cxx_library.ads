--
-- Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
--
-- This file is part of the Consistent Block Encrypter project, which is
-- distributed under the terms of the GNU Affero General Public License
-- version 3.
--

pragma Ada_2012;

with CBE.Library;
with CBE.Crypto;

package CBE.CXX.CXX_Library
with Spark_Mode
is
--	FIXME cannot be pure yet because of CBE.Library
--	pragma Pure;


	function Object_Size (Obj : Library.Object_Type)
	return CXX_Object_Size_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe11object_sizeERKNS_7LibraryE";


	procedure Initialize_Object (
		Obj     : out Library.Object_Type;
		SBs     :     Super_Blocks_Type;
		Curr_SB :     Super_Blocks_Index_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe7LibraryC2ERKNS_12Super_blocksENS_17Super_block_indexE";


	function Cache_Dirty (Obj : Library.Object_Type)
	return CXX_Bool_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZNK3Cbe7Library11cache_dirtyEv";


	function Superblock_Dirty (Obj : Library.Object_Type)
	return CXX_Bool_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZNK3Cbe7Library16superblock_dirtyEv";


	function Is_Securing_Superblock (Obj : Library.Object_Type)
	return CXX_Bool_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZNK3Cbe7Library22is_securing_superblockEv";


	function Is_Sealing_Generation (Obj : Library.Object_Type)
	return CXX_Bool_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZNK3Cbe7Library21is_sealing_generationEv";


	procedure Start_Securing_Superblock (Obj : in out Library.Object_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe7Library25start_securing_superblockEv";


	procedure Start_Sealing_Generation (Obj : in out Library.Object_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe7Library24start_sealing_generationEv";


	function Max_VBA (Obj : Library.Object_Type)
	return Virtual_Block_Address_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZNK3Cbe7Library7max_vbaEv";


	procedure Execute (
		Obj              : in out Library.Object_Type;
		Now              :        Timestamp_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe7Library7executeEy";


	function Request_Acceptable (Obj : Library.Object_Type)
	return CXX_Bool_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZNK3Cbe7Library18request_acceptableEv";


	procedure Submit_Request (
		Obj : in out Library.Object_Type;
		Req :        CXX_Request_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe7Library14submit_requestERKNS_7RequestE";


	function Peek_Completed_Request (Obj : Library.Object_Type)
	return CXX_Request_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZNK3Cbe7Library22peek_completed_requestEv";


	procedure Drop_Completed_Request (
		Obj : in out Library.Object_Type;
		Req :        CXX_Request_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe7Library22drop_completed_requestERKNS_7RequestE";


	procedure Need_Data (
		Obj : in out Library.Object_Type;
		Req :    out CXX_Request_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe7Library10_need_dataERNS_7RequestE";


	procedure Take_Read_Data (
		Obj      : in out Library.Object_Type;
		Req      :        CXX_Request_Type;
		Progress :    out CXX_Bool_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe7Library15_take_read_dataERKNS_7RequestERb";


	procedure Ack_Read_Data (
		Obj      : in out Library.Object_Type;
		Req      :        CXX_Request_Type;
		Data     :        Block_Data_Type;
		Progress :    out CXX_Bool_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe7Library14_ack_read_dataERKNS_7RequestERKNS_10Block_dataERb";


	procedure Take_Write_Data (
		Obj      : in out Library.Object_Type;
		Req      :        CXX_Request_Type;
		Data     :    out Block_Data_Type;
		Progress :    out CXX_Bool_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe7Library16_take_write_dataERKNS_7RequestERNS_10Block_dataERb";


	procedure Ack_Write_Data (
		Obj      : in out Library.Object_Type;
		Req      :        CXX_Request_Type;
		Progress :    out CXX_Bool_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe7Library15_ack_write_dataERKNS_7RequestERb";


	procedure Have_Data (
		Obj : in out Library.Object_Type;
		Req :    out CXX_Request_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe7Library10_have_dataERNS_7RequestE";


	function Give_Data_Index (
		Obj : Library.Object_Type;
		Req : CXX_Request_Type)
	return CXX_Primitive_Index_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZNK3Cbe7Library15give_data_indexERKNS_7RequestE";


	procedure Give_Read_Data (
		Obj      : in out Library.Object_Type;
		Req      :        CXX_Request_Type;
		Data     :    out Crypto.Plain_Data_Type;
		Progress :    out CXX_Bool_Type)
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe7Library15_give_read_dataERKNS_7RequestERNS_10Block_dataERb";


	function Give_Write_Data (
		Obj     : in out Library.Object_Type;
		Now     :        Timestamp_Type;
		Req     :        CXX_Request_Type;
		Data    :        Block_Data_Type)
	return CXX_Bool_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZN3Cbe7Library15give_write_dataEyRKNS_7RequestERKNS_10Block_dataE";


	function Execute_Progress (Obj : Library.Object_Type)
	return CXX_Bool_Type
	with
		Export,
		Convention    => C,
		External_Name => "_ZNK3Cbe7Library16execute_progressEv";

end CBE.CXX.CXX_Library;
