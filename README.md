# T1GFMDML and T2FMDML
T1GFMDML and T2FMDML are definitive collections of Thief 1/Gold and Thief 2 fan mission fixes for NewDark implemented with dbmods, allowing for missions and gamesystems to be patched without requiring redistribution.

Contributions are welcome and encouraged.

## Fingerprinting
In order for each dbmod to be loaded only for the intended mission or gamesystem, a `FINGERPRINT` block uniquely identifying it is required.

Currently, fixes intended for missions are fingerprinted with the positions of eight random objects in the mission that are not located at the origin and a non-zero goal target quest variable.
If no suitable quest variables are available, the unique name of an object in the mission is used instead.
Fixes intended for gamesystems are fingerprinted with either two unique archetype names or two unique archetype properties.

For more information pertaining to dbmod fingerprinting, see `dbmod-sample.dml`, which is included with the NewDark documentation.
