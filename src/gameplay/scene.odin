package scene
import building;
import planet;


Scene :: struct
{
	buildings: [dynamic]Building,
	planets: [dynamic]planet.PlanetConfig;
}