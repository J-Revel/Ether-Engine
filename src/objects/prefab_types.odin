package prefab

import "core:reflect"
import "../container"

MAX_METADATA_COUNT :: 256;
MAX_INPUT_COUNT :: 256;

// Reference to another component of the prefab
Component_Ref :: struct
{
	component_index: int,
}

Component_Input :: struct
{
	input_index: int,
}

// Reference to the field on another component of the prefab
Component_Field_Ref :: struct
{
	component_index: int,
	offset_in_component: int,
}

// Every data that a component field can have that must be computed during the prefab instantiation
Component_Field_Metadata :: union
{
	Component_Ref,
	Component_Input,
	Component_Field_Ref,
}

Component_Model_Data :: struct
{
	data: rawptr,
	metadata: [MAX_METADATA_COUNT]Component_Field_Metadata,
	metadata_offsets: [MAX_METADATA_COUNT]uintptr,
	metadata_types: [MAX_METADATA_COUNT]typeid,
	metadata_count: int,
}

Component_Model :: struct
{
	id: string,
	table_index: int,
	// TODO : maybe try with a using ?
	data: Component_Model_Data,
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

Dynamic_Prefab :: struct
{
	components: [dynamic]Component_Model,
	inputs: [dynamic]Prefab_Input
}

Prefab :: struct
{
	components: []Component_Model,
	inputs: []Prefab_Input,
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