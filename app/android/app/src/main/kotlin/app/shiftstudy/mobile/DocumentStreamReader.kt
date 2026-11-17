package app.shiftstudy.mobile

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream

internal object DocumentStreamReader {
    fun readLimited(input: InputStream, maxBytes: Int): ByteArray {
        require(maxBytes >= 0) { "maxBytes must not be negative." }
        return input.use { stream ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            var total = 0L
            while (true) {
                val count = stream.read(buffer)
                if (count < 0) break
                total += count
                if (total > maxBytes) throw IOException("Selected file is too large.")
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        }
    }
}
