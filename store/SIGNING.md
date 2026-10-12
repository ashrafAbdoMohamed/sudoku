# Release signing — Sudoku: Challenge a Friend

Everything here is set up already **except the keystore itself**, which only you
should create, because it is protected by a password only you should know.

## 1. Create the upload keystore (you run this)

```bash
mkdir -p ~/keys
keytool -genkeypair -v \
  -keystore ~/keys/sudoku-upload.jks \
  -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storetype PKCS12
```

`keytool` prompts for:

- **Keystore password** — choose a strong one, save it in your password manager now.
- **First and last name / organisation / city / country** — these become the
  certificate's distinguished name. They are not shown to users. `Rocket Game
  Station` for the organisation and `EG` for the country code are fine.
- **Key password** — press Return to reuse the keystore password. Simpler, and no
  less secure for a single-key store.

Requirements Play enforces: RSA, 2048-bit or larger, and a validity date past
22 October 2033. `-validity 10000` (~27 years) satisfies this.

## 2. Create `android/key.properties` (you run this)

Copy `android/key.properties.example` to `android/key.properties` and fill in the
two passwords you just chose:

```properties
storePassword=<your keystore password>
keyPassword=<your key password>
keyAlias=upload
storeFile=/Users/ashrafabdo/keys/sudoku-upload.jks
```

Both `key.properties` and `*.jks` are git-ignored — verify with `git status`
before you ever commit.

## 3. Build the bundle

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Verify it is signed with your key and not the debug key:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

The owner line must show your organisation, **not** `CN=Android Debug`.

## Upload key vs app signing key

Google Play App Signing means there are two keys:

| Key | Held by | If lost |
|---|---|---|
| **Upload key** (the one you just made) | You | Recoverable — Play support can reset it |
| **App signing key** | Google | Not recoverable |

Because Google holds the signing key, losing your upload key is survivable. Losing
the keystore *and* opting out of Play App Signing is not — you would never be able
to update the app, only publish a new listing under a new package name.

## Back it up

Store in at least two places you control:

- The `.jks` file itself (encrypted cloud storage, or an encrypted disk image)
- The keystore password and key alias in your password manager

Do not back it up into this git repository.

## Version bumps

`versionCode` and `versionName` come from `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

`1.0.0` is the versionName shown to users; `+1` is the versionCode Play uses.
**Play rejects any upload whose versionCode is not higher than the previous one**,
so bump the number after `+` on every single upload, even a re-upload of the same
build.
