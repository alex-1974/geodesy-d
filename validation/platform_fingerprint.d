/**
 * CI platform fingerprint for target-sensitive geodesy-d validation.
 *
 * This is validation support code, not part of the library.
 */
module platform_fingerprint;

import std.stdio : writefln, writeln;
import std.system : endian;

private string osName()
{
    version (Windows)
        return "Windows";
    else version (OSX)
        return "macOS";
    else version (linux)
        return "Linux";
    else version (FreeBSD)
        return "FreeBSD";
    else
        return "unknown";
}

private string architectureName()
{
    version (X86_64)
        return "x86_64";
    else version (X86)
        return "x86";
    else version (AArch64)
        return "AArch64";
    else version (ARM)
        return "ARM";
    else
        return "unknown";
}

private string compilerName()
{
    version (LDC)
        return "LDC";
    else version (DigitalMars)
        return "DMD";
    else version (GNU)
        return "GDC";
    else
        return "unknown";
}

void main()
{
    /*
     * IEEE binary64 is part of the numerical assumptions of the public
     * double contract.
     */
    static assert(double.sizeof == 8);
    static assert(double.mant_dig == 53);

    /*
     * D real may equal double or may be wider depending on target ABI.
     * It must never silently provide less precision than double.
     */
    static assert(real.sizeof >= double.sizeof);
    static assert(real.mant_dig >= double.mant_dig);

    writeln("geodesy-d platform fingerprint");
    writefln("os=%s", osName());
    writefln("architecture=%s", architectureName());
    writefln("compiler=%s", compilerName());
    writefln("frontend_version=%s", __VERSION__);
    writefln("endian=%s", endian);

    writefln("float.sizeof=%s", float.sizeof);
    writefln("float.mant_dig=%s", float.mant_dig);

    writefln("double.sizeof=%s", double.sizeof);
    writefln("double.mant_dig=%s", double.mant_dig);

    writefln("real.sizeof=%s", real.sizeof);
    writefln("real.alignof=%s", real.alignof);
    writefln("real.mant_dig=%s", real.mant_dig);

    writefln(
        "real_wider_than_double=%s",
        real.mant_dig > double.mant_dig
            ? "true"
            : "false");
}
