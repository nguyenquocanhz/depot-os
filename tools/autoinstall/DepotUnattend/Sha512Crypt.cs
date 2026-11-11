using System.Security.Cryptography;
using System.Text;

namespace DepotUnattend;

/// <summary>
/// Mã hoá mật khẩu kiểu "$6$" (SHA-512 crypt của glibc, giống `openssl passwd -6`) — dạng /etc/shadow đọc được.
/// Thuật toán theo đặc tả của Ulrich Drepper (https://www.akkadia.org/drepper/SHA-crypt.txt).
/// </summary>
public static class Sha512Crypt
{
    private const string Itoa64 = "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

    public static string NewSalt(int length = 16)
    {
        var sb = new StringBuilder(length);
        for (int i = 0; i < length; i++) sb.Append(Itoa64[RandomNumberGenerator.GetInt32(Itoa64.Length)]);
        return sb.ToString();
    }

    public static string Hash(string password, string? salt = null, int rounds = 5000)
    {
        salt ??= NewSalt();
        if (salt.Length > 16) salt = salt[..16];
        byte[] p = Encoding.UTF8.GetBytes(password);
        byte[] s = Encoding.ASCII.GetBytes(salt);

        byte[] b = Sha(p, s, p);

        using var a = IncrementalHash.CreateHash(HashAlgorithmName.SHA512);
        a.AppendData(p);
        a.AppendData(s);
        int len;
        for (len = p.Length; len > 64; len -= 64) a.AppendData(b);
        a.AppendData(b, 0, len);
        for (len = p.Length; len > 0; len >>= 1)
        {
            if ((len & 1) != 0) a.AppendData(b); else a.AppendData(p);
        }
        byte[] ad = a.GetHashAndReset();

        using var dpCtx = IncrementalHash.CreateHash(HashAlgorithmName.SHA512);
        for (int i = 0; i < p.Length; i++) dpCtx.AppendData(p);
        byte[] pSeq = Repeat(dpCtx.GetHashAndReset(), p.Length);

        using var dsCtx = IncrementalHash.CreateHash(HashAlgorithmName.SHA512);
        for (int i = 0; i < 16 + ad[0]; i++) dsCtx.AppendData(s);
        byte[] sSeq = Repeat(dsCtx.GetHashAndReset(), s.Length);

        byte[] c = ad;
        using var r = IncrementalHash.CreateHash(HashAlgorithmName.SHA512);
        for (int i = 0; i < rounds; i++)
        {
            if ((i & 1) != 0) r.AppendData(pSeq); else r.AppendData(c);
            if (i % 3 != 0) r.AppendData(sSeq);
            if (i % 7 != 0) r.AppendData(pSeq);
            if ((i & 1) != 0) r.AppendData(c); else r.AppendData(pSeq);
            c = r.GetHashAndReset();
        }

        var o = new StringBuilder();
        o.Append("$6$");
        if (rounds != 5000) o.Append("rounds=").Append(rounds).Append('$');
        o.Append(salt).Append('$');
        int[,] order =
        {
            { 0, 21, 42 }, { 22, 43, 1 }, { 44, 2, 23 }, { 3, 24, 45 }, { 25, 46, 4 }, { 47, 5, 26 }, { 6, 27, 48 },
            { 28, 49, 7 }, { 50, 8, 29 }, { 9, 30, 51 }, { 31, 52, 10 }, { 53, 11, 32 }, { 12, 33, 54 },
            { 34, 55, 13 }, { 56, 14, 35 }, { 15, 36, 57 }, { 37, 58, 16 }, { 59, 17, 38 }, { 18, 39, 60 },
            { 40, 61, 19 }, { 62, 20, 41 },
        };
        for (int i = 0; i < order.GetLength(0); i++) B64(o, c[order[i, 0]], c[order[i, 1]], c[order[i, 2]], 4);
        B64(o, 0, 0, c[63], 2);
        return o.ToString();
    }

    private static byte[] Sha(params byte[][] parts)
    {
        using var h = IncrementalHash.CreateHash(HashAlgorithmName.SHA512);
        foreach (var x in parts) h.AppendData(x);
        return h.GetHashAndReset();
    }

    private static byte[] Repeat(byte[] digest, int length)
    {
        var res = new byte[length];
        for (int i = 0; i < length; i++) res[i] = digest[i % 64];
        return res;
    }

    private static void B64(StringBuilder sb, byte b2, byte b1, byte b0, int n)
    {
        int w = (b2 << 16) | (b1 << 8) | b0;
        while (n-- > 0)
        {
            sb.Append(Itoa64[w & 0x3f]);
            w >>= 6;
        }
    }
}
