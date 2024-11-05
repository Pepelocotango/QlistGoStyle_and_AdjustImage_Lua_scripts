## Description [EN]
# obs-lua-scripts
This repository contains Lua scripts designed for OBS Studio, focused on managing live presentations and shows.

# Lua Scripts for OBS Studio in Live Presentations

This repository contains two Lua scripts designed to enhance the user experience of OBS Studio in live presentations, such as theater, conferences, and other live events.

## Project Status

These scripts are currently under review for official inclusion in the OBS Studio community. The approval process is managed by the core developers of the OBS Project, who evaluate the scripts to ensure their quality, security, and usefulness to the community. While we await this approval, users can test the scripts at their own risk.

## Included Scripts

### 1. Adjust image or video to screen (v1.8)

This script automatically adjusts image and video sources to fit the OBS screen, ensuring optimal visual presentation during live events.

**Main features:**
- Automatic adjustment of image and video sources to the screen
- Works with scene changes

### 2. QlistGOStyle AutoFade AudioMonitor (v1.53)

An advanced script that provides various functionalities to improve the quality of live presentations.

**Main features:**
- Automatic Transition and Fade Out for audio/video sources and Next/Previous Scene Change using hotkeys
- Automatic Audio Monitoring

## Installation

1. Download the scripts from this repository.
2. Place the `.lua` files in the OBS Studio scripts folder or any other location.
   - Windows: `%APPDATA%\obs-studio\scripts\`
   - macOS: `~/Library/Application Support/obs-studio/scripts/`
   - Linux: `~/.config/obs-studio/scripts/`
3. Open OBS Studio and go to "Tools" > "Scripts".
4. Click "+" and select the scripts you've downloaded.

## Usage

### Adjust image or video to screen
- Once activated, the script will automatically adjust image and video sources to the screen.
- No additional action is required from the user.

### QlistGOStyle AutoFade AudioMonitor
- Automatic Transition and Fade Out for audio/video sources and Next/Previous Scene Change using hotkeys
- Fade out will be automatically applied to audio sources when changing scenes.
- Audio monitoring will be automatically adjusted for all audio/video sources.

## Configuration

Each script has configuration options that can be adjusted from the OBS Studio scripts interface. Check the comments within each script for specific configuration options.

## Compatibility

These scripts have been tested in the following environments:
- Windows 10 (64-bit)
- Linux Ubuntu MATE 20.04.6 LTS (Focal Fossa) (64-bit)
- OBS Studio version 30.0.2 (64-bit)

**Note:** These scripts have not been tested on macOS.

## Contributions

Contributions are welcome! If you have any ideas to improve these scripts or want to report a bug, please open an "issue" or send a "pull request".

## License

[MIT]

## Author

[Pëpep]

---

We hope these scripts enhance your experience with OBS Studio in your live presentations!

## Acknowledgments

This project uses code from [OBS-next-scene-hotkey](https://github.com/SimonGZ/OBS-next-scene-hotkey) by SimonGZ, under the MIT license.

-------------------------------------------------------------------------------------------------------------------------------------------------------------

## Descripció [CA]
# obs-lua-scripts
Aquest repositori conté scripts en Lua dissenyats per a OBS Studio, enfocats en la gestió de presentacions en viu, live shows
# Scripts Lua per OBS Studio en Presentacions en Viu

Aquest repositori conté dos scripts Lua dissenyats per millorar l'experiència d'ús d'OBS Studio en presentacions en viu, com ara teatre, conferències i altres esdeveniments en directe.

## Estat del projecte

Aquests scripts es troben actualment en fase de revisió per a la seva inclusió oficial a la comunitat d'OBS Studio. El procés d'aprovació és gestionat pel grup de desenvolupadors principals d'OBS Project, que avaluen els scripts per assegurar-ne la qualitat, seguretat i utilitat per a la comunitat. Mentre esperem aquesta aprovació, els usuaris poden provar els scripts sota la seva pròpia responsabilitat.

## Scripts Inclosos

### 1. Adjust image or video to screen (v1.8)

Aquest script ajusta automàticament les fonts d'imatge i vídeo perquè s'adaptin a la pantalla d'OBS, garantint una presentació visual òptima durant els esdeveniments en viu.

**Característiques principals:**
- Ajust automàtic de fonts d'imatge i vídeo a la pantalla
- Funciona amb canvis d'escena

### 2. QlistGOStyle AutoFade AudioMonitor (v1.53)

Un script avançat que proporciona diverses funcionalitats per millorar la qualitat de les presentacions en directe.

**Característiques principals:**
- Transition and Fade Out Automàtic per a fonts d'àudio/video i Canvi d'Escena Següent/Anterior mitjançant tecles d'accés ràpid
- Monitorització Automàtica d'àudio

## Instal·lació

1. Descarrega els scripts d'aquest repositori.
2. Col·loca els arxius `.lua` a la carpeta de scripts d'OBS Studio. o a qualsevol altre lloc
   - Windows: `%APPDATA%\obs-studio\scripts\`
   - macOS: `~/Library/Application Support/obs-studio/scripts/`
   - Linux: `~/.config/obs-studio/scripts/`
3. Obre OBS Studio i vés a "Eines" > "Scripts".
4. Fes clic a "+" i selecciona els scripts que has descarregat.

## Ús

### Adjust image or video to screen
- Un cop activat, el script ajustarà automàticament les fonts d'imatge i vídeo a la pantalla.
- No es requereix cap acció addicional per part de l'usuari.

### QlistGOStyle AutoFade AudioMonitor
- Transition and Fade Out Automàtic per a fonts d'àudio/video i Canvi d'Escena Següent/Anterior mitjançant tecles d'accés ràpid
- El fade out s'aplicarà automàticament a les fonts d'àudio quan canviïs d'escena.
- La monitorització d'àudio s'ajustarà automàticament per a totes les fonts de audio/vídeo.

## Configuració

Cada script té opcions de configuració que es poden ajustar des de la interfície de scripts d'OBS Studio. Consulta els comentaris dins de cada script per a opcions específiques de configuració.

## Compatibilitat

Aquests scripts han estat provats en els següents entorns:
- Windows 10 (64-bit)
- Linux Ubuntu MATE 20.04.6 LTS (Focal Fossa) (64-bit)
- OBS Studio version 30.0.2 (64-bit)

**Nota:** Aquests scripts no han estat provats en macOS..

## Contribucions

Les contribucions són benvingudes! Si tens alguna idea per millorar aquests scripts o vols reportar un error, si us plau, obre un "issue" o envia un "pull request".

## Llicència

[MIT]

## Autor

[Pëpep]

---

Esperem que aquests scripts millorin la teva experiència amb OBS Studio en les teves presentacions en viu!

## Agraïments

Aquest projecte utilitza codi del [OBS-next-scene-hotkey](https://github.com/SimonGZ/OBS-next-scene-hotkey) de SimonGZ, sota llicència MIT.
