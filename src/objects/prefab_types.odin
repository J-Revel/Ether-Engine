package prefab

import "core:reflect"
import "../container"

MAX_REF_COUNT :: 256;
MAX_INPUT_COUNT :: 256;

Component_Ref :: struct
{
	component_index: int,
	field: reflect.Struct_Field,
}

Component_Model_Data :: struct
{
	data: rawptr,
	refs: [MAX_REF_COUNT]Component_Ref,
	ref_count: int,
	inputs: [MAX_REF_COUNT]Component_Input,
	input_count: int,
}

Component_Model :: struct
{
	id: string,
	table_index: int,
	data: Component_Model_Data,
}

Component_Input :: struct
{
	input_index: int,
	field: reflect.Struct_Field,
}

Prefab_Input_Type :: struct
{
	name: string,
	type_id: typeid,
}

// TODO : maybe remove Prefab_Input_Type ? Same data
Prefab_Input :: struct
{
	name: string,
	type_id: typeid
}

Prefab_Exposed_Param :: struct
{
	component_index: int,
	type_id: typeid,
	offset: uintptr,
}

Dynamic_Prefab :: struct
{
	components: [dynamic]Component_Model,
	inputs: [dynamic]Prefab_Input,
	exposed_params: [dynamic]Prefab_Exposed_Param,
}

Prefab :: struct
{
	components: []Component_Model,
	inputs: []Prefab_Input,
	exposed_params: []Prefab_Exposed_Param,
}

Named_Component :: struct(T: typeid)
{
	name: string,
	value: container.Handle(T)
}

Named_Raw_Handle :: container.Named_Element(container.Raw_Handle);

Registered_Component_Data :: struct
{
	component_index: int,
	table_index: int,
}