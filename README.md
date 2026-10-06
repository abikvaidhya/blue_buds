# Blue Buds


##
 Encrypted proximity messaging via bluetooth technology

<hr>

## Purpose

Anonymous nearby Bluetooth chat. Fully offline, private, no accounts.

## What it shows:
- Clean Flutter architecture using Riverpod as state management
- Communication via MethodChannel and EventChannel
- Clear separation between UI, state, and platform code
- Use of BLE for near-field communication
- End-to-end Encrypted communication


## Dependencies
### State & storage
flutter_riverpod:<br/>
hive: <br/>
hive_flutter:<br/>
path_provider:

### BLE (cross-platform central + peripheral)
bluetooth_low_energy:

### Crypto (E2E session keys)
cryptography: <br/>
convert: 

### UI & utils
flutter_animate: <br/>
uuid: <br/>
permission_handler: <br/>
flutter_local_notifications: <br/>
shared_preferences: <br/>
intl: 

### Image handling
image_picker: <br/>
image: 

### dev_dependencies:
flutter_test:<br/>
sdk: flutter<br/>
flutter_lints: <br/>
hive_generator:<br/>
build_runner:


## How to use

To clone and run this application, you'll need [Git](https://git-scm.com/downloads)
and [Flutter](https://flutter.dev/docs/get-started/install) installed on your computer.

### Clone this repo

```
gh repo clone abikvaidhya/blue_buds
```

### Navigate to the repo

```
cd blue_buds
```

### Install dependencies

```
flutter pub get
```

### Clean
```
flutter clean
flutter pub get
```

### Run the app