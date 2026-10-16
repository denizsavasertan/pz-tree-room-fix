import java.nio.file.*;
import java.util.*;
import org.objectweb.asm.*;
import org.objectweb.asm.tree.*;

// Runs the game's room and distance checks with isolated dependencies.
public class TreeBehaviorTest {
  public static void main(String[] args) throws Exception {
    ClassNode original = new ClassNode();
    new ClassReader(Files.readAllBytes(Path.of(args[0]))).accept(original, 0);
    
    ClassNode fixture = new ClassNode();
    new ClassReader(Files.readAllBytes(Path.of(args[1], "zombie/iso/objects/IsoTree.class"))).accept(fixture, 0);
    for (MethodNode m : original.methods) if (m.name.equals("isPlayerInsideARoom") || m.name.equals("isWithinDistanceSquared")) fixture.methods.add(m);
    ClassWriter writer = new ClassWriter(0);
    fixture.accept(writer);
    byte[] tested = writer.toByteArray();
    ClassLoader loader = new ClassLoader(TreeBehaviorTest.class.getClassLoader()) {
      protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
        if (!name.startsWith("zombie.")) return super.loadClass(name, resolve);
        Class<?> result = findLoadedClass(name);
        if (result == null) {
          try {
            byte[] b = name.equals("zombie.iso.objects.IsoTree") ? tested : Files.readAllBytes(Path.of(args[1], name.replace('.', '/') + ".class"));
            result = defineClass(name, b, 0, b.length);
          } catch (Exception e) { throw new ClassNotFoundException(name, e); }
        }
        if (resolve) resolveClass(result);
        return result;
      }
    };
    Class<?> treeType=loader.loadClass("zombie.iso.objects.IsoTree");
    Class<?> playerType=loader.loadClass("zombie.characters.IsoPlayer");
    Class<?> squareType=loader.loadClass("zombie.iso.IsoGridSquare");
    Class<?> roomType=loader.loadClass("zombie.iso.areas.IsoRoom");
    var method=treeType.getDeclaredMethod("isPlayerInsideARoom",playerType);method.setAccessible(true);
    // x,y,inside,hasRoom,expected. Camera is at (0,0).
    int[][] cases={{0,0,0,0,0},{15,15,1,1,1},{9,15,1,1,0},{28,28,1,1,1},{29,29,1,1,0},{24,0,1,0,1},{25,0,1,0,0},{0,0,1,0,1},{18,18,1,0,0}};
    for(int i=0;i<cases.length;i++){
      int[] c=cases[i];Object tree=treeType.getConstructor().newInstance(),player=playerType.getConstructor().newInstance();
      Object ts=squareType.getConstructor().newInstance(),ps=squareType.getConstructor().newInstance();
      squareType.getField("x").setInt(ts,c[0]);squareType.getField("y").setInt(ts,c[1]);treeType.getField("square").set(tree,ts);
      playerType.getField("inside").setBoolean(player,c[2]==1);playerType.getField("square").set(player,ps);
      if(c[3]==1)squareType.getField("room").set(ps,roomType.getConstructor().newInstance());
      boolean result=(boolean)method.invoke(tree,player);
      if(result!=(c[4]==1))throw new AssertionError("Case "+i+" got "+result);
      System.out.println("PASS case "+i);
    }
  }
}
