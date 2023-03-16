const std = @import("std");
const Builder = std.Build.Builder;
const CrossTarget = std.zig.CrossTarget;
const Target = std.Target;

pub fn build(b: *Builder) !void {
    const uno = CrossTarget{
        .cpu_arch = .avr,
        .cpu_model = .{ .explicit = &Target.avr.cpu.atmega328p },
        .os_tag = .freestanding,
        .abi = .none,
    };

    const exe = b.addExecutable(.{
        .name = "avr-arduino-zig",
        .target = uno,
        .optimize = .ReleaseSafe,
        .root_source_file = .{ .path = "src/start.zig" },
    });
    exe.bundle_compiler_rt = false;
    exe.setLinkerScriptPath(.{ .path = "src/linker.ld" });
    exe.install();

    const tty = b.option(
        []const u8,
        "tty",
        "Specify the port to which the Arduino is connected (defaults to /dev/ttyACM0)",
    ) orelse "/dev/ttyACM0";

    const bin_path = b.getInstallPath(exe.install_step.?.dest_dir, exe.out_filename);

    const flash_command = b.fmt("-Uflash:w: {s} :e", .{bin_path});

    const upload = b.step("upload", "Upload the code to an Arduino device using avrdude");
    const avrdude = b.addSystemCommand(&[_][]const u8{
        "avrdude",
        "-carduino",
        "-patmega328p",
        "-D",
        "-P",
        tty,
        flash_command,
    });
    upload.dependOn(&avrdude.step);
    avrdude.step.dependOn(&exe.install_step.?.step);

    const objdump = b.step("objdump", "Show dissassembly of the code using avr-objdump");
    const avr_objdump = b.addSystemCommand(&.{
        "avr-objdump",
        "-dh",
        bin_path,
    });
    objdump.dependOn(&avr_objdump.step);
    avr_objdump.step.dependOn(&exe.install_step.?.step);

    const monitor = b.step("monitor", "Opens a monitor to the serial output");
    const screen = b.addSystemCommand(&.{
        "screen",
        tty,
        "115200",
    });
    monitor.dependOn(&screen.step);

    b.default_step.dependOn(&exe.step);
}
