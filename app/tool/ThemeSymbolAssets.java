import java.awt.image.BufferedImage;
import java.awt.Color;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import javax.imageio.ImageIO;

/** Verifies StudyShift's theme S marks retain the approved master silhouette. */
public final class ThemeSymbolAssets {
  private static final String[] THEMES = {"blue", "teal", "violet", "amber", "red"};
  private static final float[] HUES = {0.57f, 0.49f, 0.75f, 0.115f, 0.99f};
  private static final String[] ASSET_NAMES = {"blue", "teal", "violet", "amber", "red"};

  public static void main(String[] args) throws IOException {
    Path app = Path.of(args.length == 0 ? "." : args[0]);
    BufferedImage master = read(app.resolve("assets/branding/studyshift-symbol.png"));
    if (args.length > 1 && args[1].equals("--inspect")) {
      for (int threshold : new int[] {1, 32, 96}) {
        inspectComponents(master, threshold);
      }
      return;
    }
    BufferedImage cleanMaster = cleanAlphaFringe(master);
    boolean generate = args.length > 1 && args[1].equals("--generate");
    for (int index = 0; index < THEMES.length; index++) {
      String theme = THEMES[index];
      String assetName = "studyshift-symbol-" + ASSET_NAMES[index] + ".png";
      Path assetPath = app.resolve("assets/branding").resolve(assetName);
      if (generate) {
        BufferedImage themed = recolor(cleanMaster, HUES[index], index == 0);
        write(themed, assetPath);
        Files.copy(
            assetPath,
            app.resolve("android/app/src/main/res/drawable-nodpi").resolve(assetName.replace('-', '_')),
            java.nio.file.StandardCopyOption.REPLACE_EXISTING);
      }
      BufferedImage icon = read(assetPath);
      requireSameAlpha(cleanMaster, icon, theme);
      if (!theme.equals("blue")) {
        requireThemeHue(icon, HUES[index], theme);
        requireReadableThemePixels(icon, HUES[index], theme);
      }
    }
    System.out.println((generate ? "Generated and verified " : "Verified ")
        + "all theme S assets against the approved master silhouette.");
  }

  private static BufferedImage recolor(BufferedImage source, float hue, boolean keepOriginalHue) {
    BufferedImage result = new BufferedImage(source.getWidth(), source.getHeight(), BufferedImage.TYPE_INT_ARGB);
    for (int y = 0; y < source.getHeight(); y++) {
      for (int x = 0; x < source.getWidth(); x++) {
        int argb = source.getRGB(x, y);
        int alpha = argb >>> 24;
        if (alpha == 0) {
          result.setRGB(x, y, argb);
          continue;
        }
        float[] hsb = Color.RGBtoHSB((argb >>> 16) & 255, (argb >>> 8) & 255, argb & 255, null);
        if (!keepOriginalHue && hsb[1] >= 0.16f) {
          float saturation = readableSaturation(hue, hsb[1]);
          int rgb = Color.HSBtoRGB(hue, saturation, 1f);
          argb = (alpha << 24) | (rgb & 0x00FFFFFF);
        }
        result.setRGB(x, y, argb);
      }
    }
    return result;
  }

  private static float readableSaturation(float hue, float originalSaturation) {
    float low = 0;
    float high = originalSaturation;
    for (int step = 0; step < 12; step++) {
      float candidate = (low + high) / 2;
      int rgb = Color.HSBtoRGB(hue, candidate, 1f);
      double luminance = (0.2126 * ((rgb >>> 16) & 255)
          + 0.7152 * ((rgb >>> 8) & 255)
          + 0.0722 * (rgb & 255)) / 255;
      if (luminance >= 0.72) low = candidate;
      else high = candidate;
    }
    return low;
  }

  private static BufferedImage cleanAlphaFringe(BufferedImage source) {
    BufferedImage result = new BufferedImage(source.getWidth(), source.getHeight(), BufferedImage.TYPE_INT_ARGB);
    int width = source.getWidth();
    int height = source.getHeight();
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int argb = source.getRGB(x, y);
        if ((argb >>> 24) < 96 && !nearOpaquePixel(source, x, y)) {
          argb &= 0x00FFFFFF;
        }
        result.setRGB(x, y, argb);
      }
    }
    return result;
  }

  private static boolean nearOpaquePixel(BufferedImage image, int x, int y) {
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        int nx = x + dx;
        int ny = y + dy;
        if (nx < 0 || nx >= image.getWidth() || ny < 0 || ny >= image.getHeight()) continue;
        if ((image.getRGB(nx, ny) >>> 24) >= 96) return true;
      }
    }
    return false;
  }

  private static void inspectComponents(BufferedImage image, int threshold) {
    int width = image.getWidth();
    int height = image.getHeight();
    boolean[] visited = new boolean[width * height];
    int[] queue = new int[width * height];
    java.util.List<Integer> sizes = new java.util.ArrayList<>();
    for (int i = 0; i < visited.length; i++) {
      int x = i % width;
      int y = i / width;
      if (visited[i] || (image.getRGB(x, y) >>> 24) < threshold) continue;
      int head = 0;
      int tail = 0;
      queue[tail++] = i;
      visited[i] = true;
      while (head < tail) {
        int pixel = queue[head++];
        int px = pixel % width;
        int py = pixel / width;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            int nx = px + dx;
            int ny = py + dy;
            if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
            int neighbor = ny * width + nx;
            if (!visited[neighbor] && (image.getRGB(nx, ny) >>> 24) >= threshold) {
              visited[neighbor] = true;
              queue[tail++] = neighbor;
            }
          }
        }
      }
      sizes.add(tail);
    }
    sizes.sort(java.util.Comparator.reverseOrder());
    System.out.println("Component sizes (alpha >= " + threshold + "): " + sizes);
  }

  private static void write(BufferedImage image, Path path) throws IOException {
    if (!ImageIO.write(image, "png", path.toFile())) {
      throw new IOException("No PNG writer is available for " + path);
    }
  }

  private static BufferedImage read(Path path) throws IOException {
    BufferedImage image = ImageIO.read(path.toFile());
    if (image == null) throw new IllegalStateException("Not a readable image: " + path);
    return image;
  }

  private static void requireSameAlpha(BufferedImage master, BufferedImage icon, String theme) {
    if (master.getWidth() != icon.getWidth() || master.getHeight() != icon.getHeight()) {
      throw new IllegalStateException("Theme " + theme + " has different artwork dimensions.");
    }
    for (int y = 0; y < master.getHeight(); y++) {
      for (int x = 0; x < master.getWidth(); x++) {
        if ((master.getRGB(x, y) >>> 24) != (icon.getRGB(x, y) >>> 24)) {
          throw new IllegalStateException(
              "Theme " + theme + " changes the approved S silhouette at " + x + "," + y + ".");
        }
      }
    }
  }

  private static void requireThemeHue(BufferedImage image, float targetHue, String theme) {
    int matchingPixels = 0;
    for (int y = 0; y < image.getHeight(); y++) {
      for (int x = 0; x < image.getWidth(); x++) {
        int argb = image.getRGB(x, y);
        if ((argb >>> 24) == 0) continue;
        float[] hsb = Color.RGBtoHSB((argb >>> 16) & 255, (argb >>> 8) & 255, argb & 255, null);
        float distance = Math.abs(hsb[0] - targetHue);
        distance = Math.min(distance, 1 - distance);
        if (hsb[1] >= 0.2f && distance <= 0.025f) matchingPixels++;
      }
    }
    if (matchingPixels < 100) {
      throw new IllegalStateException("Theme " + theme + " has too few pixels in its selected accent hue.");
    }
  }

  private static void requireReadableThemePixels(BufferedImage image, float targetHue, String theme) {
    int themedPixels = 0;
    int readablePixels = 0;
    for (int y = 0; y < image.getHeight(); y++) {
      for (int x = 0; x < image.getWidth(); x++) {
        int argb = image.getRGB(x, y);
        if ((argb >>> 24) < 96) continue;
        int red = (argb >>> 16) & 255;
        int green = (argb >>> 8) & 255;
        int blue = argb & 255;
        float[] hsb = Color.RGBtoHSB(red, green, blue, null);
        float distance = Math.abs(hsb[0] - targetHue);
        distance = Math.min(distance, 1 - distance);
        if (hsb[1] < 0.18f || distance > 0.025f) continue;
        themedPixels++;
        double luminance = (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255;
        if (luminance >= 0.72) readablePixels++;
      }
    }
    if (themedPixels < 100 || readablePixels < themedPixels * 0.9) {
      throw new IllegalStateException(
          "Theme " + theme + " accent artwork is too dark to stay distinct on its themed icon background: "
              + readablePixels + "/" + themedPixels + " readable pixels.");
    }
  }
}
