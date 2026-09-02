# 42Vienna

Repository containing 42 projects (`CPP9`, `Inception`, `IRC`).

---

## Download IRC Tester Only

If you only want to download the **IRC tester** (`IRC/tester`) into any target directory (e.g. into your own `ft_irc` project) without downloading the entire repository, use one of the copy-pastable commands below:

### One-liner download tester

Downloads directly into a folder named `tester` in your current directory:

```bash
mkdir -p tester && curl -sSL https://github.com/sugoidesune/42Vienna/archive/refs/heads/master.tar.gz | tar -xz --strip-components=3 -C tester 42Vienna-master/IRC/tester && cd tester && make help
```

> **Targeting a custom location:** Replace `tester` with your preferred destination path (e.g. `path/to/destination`).

---

## Using the Tester

Once downloaded into `tester`:

```bash
cd tester
make help
```

See [IRC/tester/README.md](file:///home/tbatis/42Vienna/IRC/tester/README.md) for full test suite documentation and options (`make case <id>`, `make parallel`, `make memory`, etc.).
