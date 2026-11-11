package app.personal.safeauth

import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import kotlin.math.pow

object Totp {
    fun code(
        secretBase32: String,
        digits: Int = 6,
        period: Int = 30,
        algorithm: String = "SHA1",
        nowMs: Long = System.currentTimeMillis(),
    ): String {
        val secret = Base32.decode(secretBase32)
        val safePeriod = if (period <= 0) 30 else period
        val counter = (nowMs / 1000L) / safePeriod
        return hotp(secret, counter, digits, algorithm)
    }

    fun remainingSeconds(period: Int = 30, nowMs: Long = System.currentTimeMillis()): Int {
        val safePeriod = if (period <= 0) 30 else period
        val seconds = nowMs / 1000L
        return (safePeriod - (seconds % safePeriod)).toInt()
    }

    fun format(code: String): String {
        return when (code.length) {
            6 -> "${code.substring(0, 3)} ${code.substring(3)}"
            8 -> "${code.substring(0, 4)} ${code.substring(4)}"
            else -> code
        }
    }

    fun nextBoundaryMs(period: Int = 30, nowMs: Long = System.currentTimeMillis()): Long {
        val safePeriodMs = (if (period <= 0) 30 else period) * 1000L
        return ((nowMs / safePeriodMs) + 1) * safePeriodMs + 40
    }

    private fun hotp(secret: ByteArray, counter: Long, digits: Int, algorithm: String): String {
        val safeDigits = digits.coerceIn(6, 8)
        val data = ByteArray(8)
        var value = counter
        for (i in 7 downTo 0) {
            data[i] = (value and 0xff).toByte()
            value = value ushr 8
        }
        val mac = Mac.getInstance(hmacName(algorithm))
        mac.init(SecretKeySpec(secret, mac.algorithm))
        val digest = mac.doFinal(data)
        val offset = digest[digest.size - 1].toInt() and 0x0f
        val binary =
            ((digest[offset].toInt() and 0x7f) shl 24) or
                ((digest[offset + 1].toInt() and 0xff) shl 16) or
                ((digest[offset + 2].toInt() and 0xff) shl 8) or
                (digest[offset + 3].toInt() and 0xff)
        val otp = binary % 10.0.pow(safeDigits).toInt()
        return otp.toString().padStart(safeDigits, '0')
    }

    private fun hmacName(algorithm: String): String {
        return when (algorithm.uppercase().replace("-", "")) {
            "SHA256" -> "HmacSHA256"
            "SHA512" -> "HmacSHA512"
            else -> "HmacSHA1"
        }
    }
}

object Base32 {
    private const val alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    fun decode(input: String): ByteArray {
        val cleaned = input.trim().replace("=", "").replace(" ", "").replace("-", "").uppercase()
        require(cleaned.isNotEmpty()) { "Empty secret" }
        var buffer = 0
        var bits = 0
        val out = ArrayList<Int>()
        for (char in cleaned) {
            val value = alphabet.indexOf(char)
            require(value >= 0) { "Invalid Base32 character: $char" }
            buffer = (buffer shl 5) or value
            bits += 5
            if (bits >= 8) {
                bits -= 8
                out.add((buffer shr bits) and 0xFF)
            }
        }
        return ByteArray(out.size) { out[it].toByte() }
    }
}
