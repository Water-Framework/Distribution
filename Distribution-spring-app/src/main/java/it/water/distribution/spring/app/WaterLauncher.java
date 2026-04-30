package it.water.distribution.spring.app;

import it.water.implementation.spring.bundle.WaterPropertiesPropertySource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.context.ApplicationContextInitializer;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.io.DefaultResourceLoader;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

public class WaterLauncher {

    private static final Logger log = LoggerFactory.getLogger(WaterLauncher.class);

    public static void main(String[] args) throws Exception {
        URLClassLoader extLoader = buildAndSetExtendedClassLoader();
        Properties externalProps = loadExternalJarProperties();

        SpringApplication app = new SpringApplication(WaterSpringApplication.class);
        if (extLoader != null) {
            app.setResourceLoader(new DefaultResourceLoader(extLoader));
        }
        if (!externalProps.isEmpty()) {
            app.addInitializers((ApplicationContextInitializer<ConfigurableApplicationContext>) ctx ->
                ctx.getEnvironment().getPropertySources().addLast(
                    new WaterPropertiesPropertySource("waterExternalJarProperties", externalProps)
                )
            );
        }
        app.run(args);
    }

    static URLClassLoader buildAndSetExtendedClassLoader() throws IOException {
        String extraDir = resolveExtraClasspathDir();

        if (extraDir.isBlank()) {
            log.info("[ExtraClasspath] No extra classpath directory configured (water.extra.classpath.dir is empty)");
            return null;
        }

        File dir = new File(extraDir);
        if (!dir.isDirectory()) {
            log.warn("[ExtraClasspath] Configured directory does not exist or is not a directory: {}", extraDir);
            return null;
        }

        File[] jars = dir.listFiles(f -> f.getName().endsWith(".jar"));
        if (jars == null || jars.length == 0) {
            log.info("[ExtraClasspath] Directory found but contains no .jar files: {}", extraDir);
            return null;
        }

        List<URL> extraUrls = new ArrayList<>();
        for (File jar : jars) {
            extraUrls.add(jar.toURI().toURL());
            log.info("[ExtraClasspath] Adding JAR: {}", jar.getName());
        }

        ClassLoader parent = Thread.currentThread().getContextClassLoader();
        URLClassLoader extLoader = new URLClassLoader(extraUrls.toArray(new URL[0]), parent);
        Thread.currentThread().setContextClassLoader(extLoader);
        log.info("[ExtraClasspath] {} JAR(s) loaded from: {}", jars.length, extraDir);
        return extLoader;
    }

    static String resolveExtraClasspathDir() {
        try (InputStream is = WaterLauncher.class.getResourceAsStream("/application.properties")) {
            if (is == null) return fallbackEnvVar();
            Properties props = new Properties();
            props.load(is);
            String value = props.getProperty("water.extra.classpath.dir", "").trim();
            return resolvePlaceholder(value);
        } catch (IOException e) {
            log.warn("[ExtraClasspath] Failed to read application.properties: {}", e.getMessage());
            return fallbackEnvVar();
        }
    }

    static String resolvePlaceholder(String value) {
        if (!value.startsWith("${") || !value.endsWith("}")) return value;
        String inner = value.substring(2, value.length() - 1);
        int colon = inner.indexOf(':');
        String envKey = colon >= 0 ? inner.substring(0, colon) : inner;
        String defaultVal = colon >= 0 ? inner.substring(colon + 1) : "";
        String resolved = System.getenv(envKey);
        if (resolved == null) resolved = System.getProperty(envKey);
        return resolved != null ? resolved : defaultVal;
    }

    private static String fallbackEnvVar() {
        String val = System.getenv("EXTRA_CLASSPATH_DIR");
        return val != null ? val : "";
    }

    static Properties loadExternalJarProperties() {
        String extraDir = resolveExtraClasspathDir();
        if (extraDir.isBlank()) return new Properties();

        File dir = new File(extraDir);
        if (!dir.isDirectory()) return new Properties();

        File[] jars = dir.listFiles(f -> f.getName().endsWith(".jar"));
        if (jars == null || jars.length == 0) return new Properties();

        Properties merged = new Properties();
        for (File jar : jars) {
            try (JarFile jarFile = new JarFile(jar)) {
                JarEntry entry = jarFile.getJarEntry("it.water.application.properties");
                if (entry == null) continue;
                try (InputStream is = jarFile.getInputStream(entry)) {
                    Properties p = new Properties();
                    p.load(is);
                    merged.putAll(p);
                    log.info("[ExtraClasspath] Loaded it.water.application.properties from: {}", jar.getName());
                }
            } catch (IOException e) {
                log.warn("[ExtraClasspath] Failed to read properties from JAR {}: {}", jar.getName(), e.getMessage());
            }
        }
        merged.forEach((k, v) -> log.info("[ExtraClasspath] Property loaded: {}={}", k, v));
        return merged;
    }
}