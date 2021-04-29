package audio

import sdl "shared:odin-sdl2"
import "core:math"
import "core:runtime"
import "core:log"
import "core:mem"
import "core:math/rand"

Audio_Format :: enum u16{
	U8 = 0x0008,
	S8 = 0x8008,
	U16LSB = 0x0010,
	U16MSB = 0x9010,
	S32LSB = 0x8020,
	S32MSB = 0x9020,
	F32LSB = 0x8120,
	F32MSB = 0x9120,
}

Audio_Change_Type :: enum i32 {
	Allow_Frequency_Change 	= 0x00000001,
	Allow_Format_Change 	= 0x00000002,
	Allow_Channels_Change 	= 0x00000004,
	Allow_Samples_Change	= 0x00000008,
}

wav_pos: ^u8;
wav_len: u32;
time: f32;
random: rand.Rand;
random_float := rand.float32;

audio_callback :: proc "c" (user_data: rawptr, stream: ^u8, len: i32)
{
	context = {};
	audio_system_data := cast(^Audio_System_Data)user_data;
	for i in 0..<len/size_of(f32)
	{
		value := cast(^f32)(uintptr(rawptr(stream)) + uintptr(i * size_of(f32)));
		sample_time := time + f32(i); 
		value^ = 0.2 * math.sin(2 * math.PI * sample_time * 440 / 96000);
	}
	time += f32(4096);
}

audio_spec := sdl.Audio_Spec {
	freq = 96000,
	format = u16(Audio_Format.F32LSB),
	channels = 1,
	samples = 4096,
};

load_wav :: proc(file: cstring, spec: ^sdl.Audio_Spec, audio_buf: ^^u8, audio_len: ^u32) -> ^sdl.Audio_Spec
{
	return sdl.load_wav_rw(sdl.rw_from_file(file, "rb"), 1, spec, audio_buf, audio_len);
}

set_sound_freq :: proc(f: f32)
{
	data := cast(^f32)(audio_spec.userdata);
	data^ = f;
}

Audio_System_Data :: struct
{
	random: rand.Rand,

}

init_audio_system :: proc()
{
	random = rand.create(123546);
	audio_spec.callback = audio_callback;
	audio_system_data := new(Audio_System_Data);
	audio_spec.userdata = rawptr(audio_system_data);
	audio_device := sdl.open_audio_device(nil, 0, &audio_spec, &audio_spec, i32(Audio_Change_Type.Allow_Frequency_Change));
	log.info(audio_spec);
	sdl.pause_audio_device(audio_device, 0);
	wav_buffer: ^u8;
	if load_wav("resources/audio/music.wav", &audio_spec, &wav_buffer, &wav_len) == nil
	{
		log.info("ERROR LOADING MUSIC");
	}
	wav_pos = wav_buffer;
}
