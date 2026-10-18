# Protoss Mech - Test Build

Feel free to download and play, but **please do not upload to the Steam Workshop or share the files directly.** If you want to share it, please send the link of this repository.

**Note before downloading:**
1. This is a test version; updates may be frequent and could change core mechanics.
2. Art assets (textures) may be missing or use placeholders.

**Requirement:**
This mod requires [PandaLib](https://github.com/RedstonePanda00/PandaLib).

Future development targets RimWorld 1.7 only. Open the projects in `Source/1.7`
directly in Rider, or build from the repository root:

```powershell
dotnet build Source/1.7/ProtossMech/ProtossMech.csproj
dotnet build Source/1.7/GunSmithFramework.CE/GunSmithFramework.CE.csproj
```

Both projects build their `GunSmithFramework` dependency automatically. Outputs go
to `1.7/Assemblies` and `1.7/CE/Assemblies`; the installed RimWorld 1.7 directory
can be overridden with `-p:RimWorldDir="path"`.
The 1.6 release is frozen; its projects remain in `Source/ProtossMech` for reference.
Shared Textures, Sounds and Languages remain at the mod root.
Third-party 1.7 compatibility packs are deferred.

Authoring projects, migration documentation and test output are stored in the sibling
`ProtossMechCore-LatestBackup/Migration17-20261013` directory. Shader export reads
its `Authoring/UnityExport` project; build intermediates and isolated test saves go
to its `artifacts` directory. See `Docs/Compatibility/RimWorld17Migration.md` there
for migration details and verification scope.

The former `Tools` directory is archived in
`ProtossMechCore-LatestBackup/ToolsCleanup-20261018-114325/Tools`.
These historical scripts are not required for normal builds and retain their
original migration-era paths; review them before reuse.
