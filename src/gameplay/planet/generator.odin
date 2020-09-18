package planet;

import "core:math"
import "core:math/rand"

generate :: proc(result: ^Config, r: f32, harmonicCount: int) 
{
	result.r = r;
	for i := 0; i < harmonicCount; i+=1
	{
		harmonic := ShapeHarmonic{0.2, 1};
		harmonic.f = rand.float32() / cast(f32) (i * 2 + 1) / 3;
		harmonic.offset = rand.float32() * 2 * math.PI;
		append(&result.harmonics, harmonic);
	}
}