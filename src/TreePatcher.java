import java.nio.file.*;
import java.security.*;
import java.util.*;
import java.util.jar.*;
import org.objectweb.asm.*;
import org.objectweb.asm.tree.*;

public final class TreePatcher {
  static final String ENTRY = "zombie/iso/objects/IsoTree.class";
  static final String ORIGINAL = "48b8b8aa39dbbb534700c2e979c6b38097cdcfab2938786f1b56166e510f396a";

  static byte[] patch(byte[] bytes) throws Exception {
    String hash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
    if (!ORIGINAL.equals(hash)) throw new IllegalArgumentException("Unsupported IsoTree.class SHA-256: " + hash + ". No files changed.");
    ClassNode cls = new ClassNode();
    new ClassReader(bytes).accept(cls, 0);
    MethodNode method = cls.methods.stream().filter(m -> m.name.equals("isPlayerInsideARoom") && m.desc.equals("(Lzombie/characters/IsoPlayer;)Z")).findFirst().orElseThrow();
    int changes = 0;
    for (AbstractInsnNode node : method.instructions.toArray()) {
      if (node instanceof MethodInsnNode call && call.owner.equals("zombie/iso/areas/IsoRoom")
          && call.name.equals("getRectsBounds") && call.desc.equals("()Ljava/awt/Rectangle;")) {
        // Preserve normal room geometry; player-built regions may have no IsoRoom.
        LabelNode hasRoom = new LabelNode();
        InsnList guard = new InsnList();
        guard.add(new InsnNode(Opcodes.DUP));
        guard.add(new JumpInsnNode(Opcodes.IFNONNULL, hasRoom));
        guard.add(new InsnNode(Opcodes.POP));
        guard.add(new VarInsnNode(Opcodes.ALOAD, 0));
        guard.add(new LdcInsnNode(24.0f));
        guard.add(new MethodInsnNode(Opcodes.INVOKEVIRTUAL, "zombie/iso/objects/IsoTree", "isWithinDistanceSquared", "(F)Z", false));
        guard.add(new InsnNode(Opcodes.IRETURN));
        guard.add(hasRoom);
        guard.add(new FrameNode(Opcodes.F_FULL, 2, new Object[]{"zombie/iso/objects/IsoTree", "zombie/characters/IsoPlayer"}, 1, new Object[]{"zombie/iso/areas/IsoRoom"}));
        method.instructions.insertBefore(node, guard);
        changes++;
      }
    }
    if (changes != 1) throw new IllegalStateException("Expected one room bounds call, got " + changes);
    ClassWriter writer = new ClassWriter(0);
    cls.accept(writer);
    return writer.toByteArray();
  }

  public static void main(String[] args) throws Exception {
    if (args.length != 2) throw new IllegalArgumentException("Usage: TreePatcher <projectzomboid.jar> <new-output.class>");
    byte[] original;
    try (JarFile jar = new JarFile(args[0])) {
      var entry = jar.getJarEntry(ENTRY);
      if (entry == null) throw new IllegalArgumentException("IsoTree.class not found");
      try (var in = jar.getInputStream(entry)) { original = in.readAllBytes(); }
    }
    byte[] patched = patch(original);
    Files.write(Path.of(args[1]), patched, StandardOpenOption.CREATE_NEW);
    System.out.println("Patched missing-room distance fallback. World data unchanged. SHA-256="
        + HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(patched)));
  }
}
