# Work Documentation

**Regular Updates**

### Main Workflow:

1. Create actual work directories and files.
2. Copy files.
3. Create a `.deb` package.

Users are allowed to modify or rebuild the work directory, e.g., `/lib/systemd/system/hubv3.service`.

---

### Commands

**Clear All Work Traces**
```shell
./build.sh --clean
```

- When users create different `.deb` packages, they don't interfere with each other.

**Rebuild**
```shell
./build.sh --rebuild
```

- Deletes data within the work directory and rebuilds it. This is useful when user data becomes disorganized.

- During rebuild, some files from the current directory are copied to the work directory.

**Compile `.deb` Package**
```shell
./build.sh
```

- If files already exist within the work directory, they will generally not be overwritten by files from the current directory. This facilitates editing until the rebuild command is issued.
