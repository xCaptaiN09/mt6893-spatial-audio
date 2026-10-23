import java.io.File;
import java.io.FileOutputStream;
import java.lang.reflect.Constructor;
import java.lang.reflect.Method;

/** Direct 7.1.4 AudioTrack client; twelve channels, including four heights. */
public final class SpatialPlaybackProbe {
    static final int RATE = 48000;
    static final int CHANNELS = 12;
    static final int SECONDS = 24;
    static final String[] CHANNEL_NAMES = {
        "Front left", "Front right", "Front centre", "LFE / bass",
        "Back left", "Back right", "Side left", "Side right",
        "Top front left", "Top front right", "Top back left", "Top back right"
    };

    static void phase(File directory, String value) throws Exception {
        File temporary = new File(directory, "phase.tmp");
        try (FileOutputStream out = new FileOutputStream(temporary)) {
            out.write((value + "\n").getBytes("UTF-8"));
        }
        if (!temporary.renameTo(new File(directory, "phase.txt"))) {
            throw new IllegalStateException("Cannot publish playback phase");
        }
    }

    static Object call(Object object, String name) throws Exception {
        return object.getClass().getMethod(name).invoke(object);
    }

    static void channel(File directory, String value) throws Exception {
        File temporary = new File(directory, "channel.tmp");
        try (FileOutputStream out = new FileOutputStream(temporary)) {
            out.write((value + "\n").getBytes("UTF-8"));
        }
        if (!temporary.renameTo(new File(directory, "channel.txt"))) {
            throw new IllegalStateException("Cannot publish channel label");
        }
    }

    static void query(Object attributes, Object format) {
        try {
            Class<?> looper = Class.forName("android.os.Looper");
            if (looper.getMethod("myLooper").invoke(null) == null) {
                looper.getMethod("prepareMainLooper").invoke(null);
            }
            Class<?> activityThread = Class.forName("android.app.ActivityThread");
            Object thread = activityThread.getMethod("systemMain").invoke(null);
            Object context = activityThread.getMethod("getSystemContext").invoke(thread);
            Object manager = Class.forName("android.content.Context")
                .getMethod("getSystemService", String.class).invoke(context, "audio");
            Object spatializer = Class.forName("android.media.AudioManager")
                .getMethod("getSpatializer").invoke(manager);
            Class<?> spatializerClass = Class.forName("android.media.Spatializer");
            for (String name : new String[]{"isEnabled", "isAvailable", "getImmersiveAudioLevel"}) {
                System.out.println("Spatializer." + name + "="
                    + spatializerClass.getMethod(name).invoke(spatializer));
            }
            System.out.println("Spatializer.canBeSpatialized=" + spatializerClass
                .getMethod("canBeSpatialized", Class.forName("android.media.AudioAttributes"),
                           Class.forName("android.media.AudioFormat"))
                .invoke(spatializer, attributes, format));
        } catch (Throwable error) {
            // Capability querying is optional; actual track creation/dumps remain useful.
            System.out.println("Capability query unavailable: " + error);
        }
    }

    static Object attributes(boolean bypass) throws Exception {
        Class<?> type = Class.forName("android.media.AudioAttributes");
        Class<?> builderClass = Class.forName("android.media.AudioAttributes$Builder");
        Object builder = builderClass.getConstructor().newInstance();
        builderClass.getMethod("setUsage", int.class).invoke(builder, type.getField("USAGE_MEDIA").getInt(null));
        builderClass.getMethod("setContentType", int.class).invoke(builder, type.getField("CONTENT_TYPE_MOVIE").getInt(null));
        int behavior = type.getField(bypass ? "SPATIALIZATION_BEHAVIOR_NEVER"
                                            : "SPATIALIZATION_BEHAVIOR_AUTO").getInt(null);
        builderClass.getMethod("setSpatializationBehavior", int.class).invoke(builder, behavior);
        builderClass.getMethod("setIsContentSpatialized", boolean.class).invoke(builder, false);
        return builderClass.getMethod("build").invoke(builder);
    }

    static Object format() throws Exception {
        Class<?> type = Class.forName("android.media.AudioFormat");
        Class<?> builderClass = Class.forName("android.media.AudioFormat$Builder");
        Object builder = builderClass.getConstructor().newInstance();
        builderClass.getMethod("setEncoding", int.class).invoke(builder, type.getField("ENCODING_PCM_16BIT").getInt(null));
        builderClass.getMethod("setSampleRate", int.class).invoke(builder, RATE);
        int mask = type.getField("CHANNEL_OUT_7POINT1POINT4").getInt(null);
        if (mask != 0x000b58fc || Integer.bitCount(mask) != CHANNELS) {
            throw new IllegalStateException("Unexpected 7.1.4 channel mask=" + mask);
        }
        builderClass.getMethod("setChannelMask", int.class).invoke(builder, mask);
        return builderClass.getMethod("build").invoke(builder);
    }

    static void play(File directory, boolean bypass) throws Exception {
        String phaseName = bypass ? "NEVER" : "AUTO";
        Class<?> trackClass = Class.forName("android.media.AudioTrack");
        Class<?> formatClass = Class.forName("android.media.AudioFormat");
        Object attributes = attributes(bypass);
        Object format = format();
        System.out.println("\nPHASE " + phaseName + ": 7.1.4 PCM16, 48000 Hz, " + SECONDS + " seconds");
        System.out.println("Attributes: " + attributes);
        System.out.println("Format: " + format);
        if (!bypass) query(attributes, format);
        int mask = formatClass.getField("CHANNEL_OUT_7POINT1POINT4").getInt(null);
        int encoding = formatClass.getField("ENCODING_PCM_16BIT").getInt(null);
        int minimum = (Integer) trackClass.getMethod("getMinBufferSize", int.class, int.class, int.class)
            .invoke(null, RATE, mask, encoding);
        if (minimum <= 0) throw new IllegalStateException("getMinBufferSize=" + minimum);
        int streamMode = trackClass.getField("MODE_STREAM").getInt(null);
        Constructor<?> constructor = trackClass.getConstructor(
            Class.forName("android.media.AudioAttributes"), formatClass, int.class, int.class, int.class);
        Object track = constructor.newInstance(attributes, format,
            Math.max(minimum * 2, RATE * CHANNELS * 2 / 4), streamMode, 0);
        try {
            int state = (Integer) call(track, "getState");
            if (state != trackClass.getField("STATE_INITIALIZED").getInt(null)) {
                throw new IllegalStateException("AudioTrack state=" + state);
            }
            if ((Integer) call(track, "getChannelCount") != CHANNELS) {
                throw new IllegalStateException("Track is not twelve channels");
            }
            System.out.println("Session=" + call(track, "getAudioSessionId")
                + "; channels=" + call(track, "getChannelCount")
                + "; sampleRate=" + call(track, "getSampleRate"));
            System.out.println("Actual attributes: " + call(track, "getAudioAttributes"));
            int volumeStatus = (Integer) trackClass.getMethod("setVolume", float.class).invoke(track, 0.5f);
            if (volumeStatus != 0) throw new IllegalStateException("Per-track gain failed=" + volumeStatus);
            Method write = trackClass.getMethod("write", short[].class, int.class, int.class);
            trackClass.getMethod("play").invoke(track);
            short[] block = new short[480 * CHANNELS];
            int random = 0x4d543639;
            double lowPass = 0.0;
            int previousSlot = -1;
            long written = 0;
            long total = (long) RATE * SECONDS;
            while (written < total) {
                int frames = (int) Math.min(480, total - written);
                for (int frame = 0; frame < frames; frame++) {
                    long position = written + frame;
                    int slot = (int) (position / (RATE * 2L));
                    int channel = slot % CHANNELS;
                    if (slot != previousSlot) {
                        System.out.println(phaseName + " channel: " + CHANNEL_NAMES[channel]);
                        channel(directory, phaseName + " | " + CHANNEL_NAMES[channel]);
                        previousSlot = slot;
                    }
                    double localTime = (position % (RATE * 2L)) / (double) RATE;
                    double envelope = localTime < 1.5
                        ? Math.max(0.0, Math.min(1.0, Math.min(localTime / 0.03, (1.5 - localTime) / 0.03)))
                        : 0.0;
                    random = random * 1664525 + 1013904223;
                    double white = ((random >>> 8) / 8388608.0) - 1.0;
                    lowPass = 0.9 * lowPass + 0.1 * white;
                    double signal = channel == 3 ? 0.05 * Math.sin(2 * Math.PI * 70 * localTime)
                        : 0.12 * (0.35 * white + 0.65 * lowPass);
                    short sample = (short) Math.round(32767.0 * signal * envelope);
                    for (int c = 0; c < CHANNELS; c++) block[frame * CHANNELS + c] = c == channel ? sample : 0;
                }
                int count = frames * CHANNELS;
                int offset = 0;
                while (offset < count) {
                    int result = (Integer) write.invoke(track, block, offset, count - offset);
                    if (result <= 0) throw new IllegalStateException("AudioTrack.write=" + result);
                    offset += result;
                }
                written += frames;
                if (written == frames) phase(directory, phaseName);
            }
            long drainDeadline = System.currentTimeMillis() + 3000;
            while ((Integer) call(track, "getPlaybackHeadPosition") < written) {
                if (System.currentTimeMillis() > drainDeadline) throw new IllegalStateException("Playback did not drain completely");
                Thread.sleep(50);
            }
            System.out.println(phaseName + " submitted frames=" + written
                + "; playbackHead=" + call(track, "getPlaybackHeadPosition"));
        } finally {
            try { trackClass.getMethod("stop").invoke(track); } catch (Throwable ignored) { }
            trackClass.getMethod("release").invoke(track);
        }
    }

    public static void main(String[] arguments) {
        if (arguments.length != 1) throw new IllegalArgumentException("Expected work directory");
        File directory = new File(arguments[0]);
        try {
            System.out.println("MT6893 7.1.4 channel check; one 24-second AUTO stream");
            System.out.println("No global setting, policy state, system volume or module changes.");
            play(directory, false);
            phase(directory, "DONE");
            System.out.println("RESULT: stream completed; processing evidence and listening still need review.");
            System.exit(0);
        } catch (Throwable error) {
            error.printStackTrace(System.out);
            try { phase(directory, "ERROR"); } catch (Throwable ignored) { }
            System.exit(2);
        }
    }
}
