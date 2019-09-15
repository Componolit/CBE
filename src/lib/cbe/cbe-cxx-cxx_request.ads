--
-- Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
--
-- This file is part of the Consistent Block Encrypter project, which is
-- distributed under the terms of the GNU Affero General Public License
-- version 3.
--

pragma Ada_2012;

with CBE.Request;

package CBE.CXX.CXX_Request
with Spark_Mode
is
	pragma Pure;

	type Success_Type is range 0..1 with Size => 32;

	--
	-- Object_Type
	--
	type Object_Type is record
		Operation    : CXX_Operation_Type;
		Success      : Success_Type;
		Block_Number : CXX_Block_Number_Type;
		Offset       : Uint64_Type;
		Count        : Uint32_Type;
		Tag          : CXX_Tag_Type;
	end record; pragma Pack(Object_Type);

	--
	-- Success_From_Spark
	--
	function Success_From_Spark(Success : in Request.Success_Type)
	return Success_Type;

	--
	-- Op_From_Spark
	--
	function Op_From_Spark(Op : in Operation_Type)
	return CXX_Operation_Type;

	--
	-- To_Spark
	--
	function To_Spark(Obj : in Object_Type)
	return Request.Object_Type;

	--
	-- Success_To_Spark
	--
	function Success_To_Spark(Success : in Success_Type)
	return Request.Success_Type;

	--
	-- From_spark
	--
	function From_Spark(Obj : in Request.Object_Type)
	return Object_Type;

end CBE.CXX.CXX_Request;
