package util

FRAME_SAMPLE_COUNT :: 10;

sample_frame_times: [FRAME_SAMPLE_COUNT]f32;
frame_index := 0;

register_frame_sample :: proc(delta_time: f32)
{
	sample_frame_times[frame_index % FRAME_SAMPLE_COUNT] = delta_time;
	frame_index += 1;
}

get_fps :: proc() -> f32
{
	sample_time_sum: f32 = 0;
	for i in 0..<FRAME_SAMPLE_COUNT do sample_time_sum += sample_frame_times[i];
	return FRAME_SAMPLE_COUNT / sample_time_sum;
}

