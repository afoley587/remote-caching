/*
 * This Java source file was generated by the Gradle 'init' task.
 */
package io.engineeringwithalex.app;

import org.junit.Test;
import static org.junit.Assert.*;

public class AppTest {
    @Test public void appHasAGreeting() throws InterruptedException {
        App classUnderTest = new App();
        Thread.sleep(10_000); // makes the test longer
        assertNotNull("app should have a greeting", classUnderTest.getGreeting());
    }
}
