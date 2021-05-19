package audio

import sdl "shared:odin-sdl2"
import mixer "shared:odin-sdl2/mixer"
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
		//value^ = 0.2 * math.sin(2 * math.PI * sample_time * 440 / f32(audio_system_data.freq));
		for clip in audio_system_data.playing_clips
		{
			value^ = (cast(^f32)mem.ptr_offset(clip.data, int(clip.play_cursor) + int(i) * size_of(f32)))^;
		}
	}
	for clip in &audio_system_data.playing_clips
	{
		clip.play_cursor += int(len/size_of(f32)) * size_of(f32);
	}
	time += f32(4096);
}


load_wav :: proc(file: cstring, spec: ^sdl.Audio_Spec, audio_buf: ^^u8, audio_len: ^u32) -> ^sdl.Audio_Spec
{
	return sdl.load_wav_rw(sdl.rw_from_file(file, "rb"), 1, spec, audio_buf, audio_len);
}

Audio_System :: struct
{
	spec: sdl.Audio_Spec,
	audio_system_data: Audio_System_Data,
}

Audio_System_Data :: struct
{
	using spec: ^sdl.Audio_Spec,
	playing_clips: [dynamic]Audio_Clip,
}

Audio_Clip :: struct
{
	spec: sdl.Audio_Spec,
	data: ^u8,
	data_size: int,
	play_cursor: int,
}

init_audio_system :: proc(audio_system: ^Audio_System)
{
	audio_spec := sdl.Audio_Spec {
		freq = 96000,
		format = u16(Audio_Format.F32LSB),
		channels = 1,
		samples = 4096,
	};
	random = rand.create(123546);
	mixer.init(i32(mixer.Init_Flags.mp3));
	if mixer.open_audio(22050, u16(Audio_Format.F32LSB), 2, 1024) < 0 {
		log.info("ERROR LOADING MIXER LIB");
	}
	music := mixer.load_wav("resources/audio/music.wav");
	if music == nil
	{
		log.info("ERROR LOADING MUSIC");
	}
	//mixer.play_channel_timed(-1, music, 0, 0);
}
