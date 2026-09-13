/* SPDX-License-Identifier: GPL-2.0 */
#include "header_protection.h"
#include "device.h"

#include <asm/unaligned.h>
#include <linux/string.h>

#define ROTL32(v, n) (((v) << (n)) | ((v) >> (32 - (n))))
#define CHACHA_QR(a, b, c, d) do { \
	a += b; d ^= a; d = ROTL32(d, 16); \
	c += d; b ^= c; b = ROTL32(b, 12); \
	a += b; d ^= a; d = ROTL32(d, 8);  \
	c += d; b ^= c; b = ROTL32(b, 7);  \
} while (0)

static void chacha20_block(u32 *out, const u32 *in)
{
	int i;
	for (i = 0; i < 16; ++i)
		out[i] = in[i];
	for (i = 0; i < 10; ++i) {
		CHACHA_QR(out[0], out[4], out[8],  out[12]);
		CHACHA_QR(out[1], out[5], out[9],  out[13]);
		CHACHA_QR(out[2], out[6], out[10], out[14]);
		CHACHA_QR(out[3], out[7], out[11], out[15]);
		CHACHA_QR(out[0], out[5], out[10], out[15]);
		CHACHA_QR(out[1], out[6], out[11], out[12]);
		CHACHA_QR(out[2], out[7], out[8],  out[13]);
		CHACHA_QR(out[3], out[4], out[9],  out[14]);
	}
	for (i = 0; i < 16; ++i)
		out[i] += in[i];
}

void chacha20_crypt(struct chacha_state *state, u8 *dst, const u8 *src, unsigned int bytes)
{
	u8 stream[64];
	u32 block[16];
	unsigned int i, cur;

	while (bytes > 0) {
		chacha20_block(block, state->x);
		state->x[12]++;
		for (i = 0; i < 16; ++i)
			put_unaligned_le32(block[i], stream + i * 4);
		cur = min_t(unsigned int, bytes, 64);
		for (i = 0; i < cur; ++i)
			dst[i] = src[i] ^ stream[i];
		bytes -= cur;
		src += cur;
		dst += cur;
	}
}

static inline void chacha_init_state(struct chacha_state *state, const u32 *key, const u8 *iv)
{
	state->x[0]  = 0x61707865;
	state->x[1]  = 0x3320646e;
	state->x[2]  = 0x79622d32;
	state->x[3]  = 0x6b206574;
	state->x[4]  = key[0];
	state->x[5]  = key[1];
	state->x[6]  = key[2];
	state->x[7]  = key[3];
	state->x[8]  = key[4];
	state->x[9]  = key[5];
	state->x[10] = key[6];
	state->x[11] = key[7];
	state->x[12] = get_unaligned_le32(iv + 0);
	state->x[13] = get_unaligned_le32(iv + 4);
	state->x[14] = get_unaligned_le32(iv + 8);
	state->x[15] = get_unaligned_le32(iv + 12);
}

bool awg_header_protection_init(struct chacha_state *state, struct wg_device *wg, u8 *nonce)
{
	struct header_protection *p = &wg->header_protection;
	bool res = false;
	u8 iv[16];

	down_read(&p->lock);
	if (!p->has_protection)
		goto out;

	memset(iv, 0, 4);
	memcpy(iv + 4, nonce, 12);

	chacha_init_state(state, p->key, iv);
	res = true;
out:
	up_read(&p->lock);
	return res;
}

void awg_header_protection_set_key(struct header_protection *p, const u8 key[HEADER_PROTECTION_KEY_SIZE])
{
	down_write(&p->lock);
	p->key[0] = get_unaligned_le32(key + 0);
	p->key[1] = get_unaligned_le32(key + 4);
	p->key[2] = get_unaligned_le32(key + 8);
	p->key[3] = get_unaligned_le32(key + 12);
	p->key[4] = get_unaligned_le32(key + 16);
	p->key[5] = get_unaligned_le32(key + 20);
	p->key[6] = get_unaligned_le32(key + 24);
	p->key[7] = get_unaligned_le32(key + 28);
	p->has_protection = true;
	up_write(&p->lock);
}

void awg_header_protection_get_key(struct header_protection *p, u8 key[HEADER_PROTECTION_KEY_SIZE])
{
	down_read(&p->lock);
	put_unaligned_le32(p->key[0], key + 0);
	put_unaligned_le32(p->key[1], key + 4);
	put_unaligned_le32(p->key[2], key + 8);
	put_unaligned_le32(p->key[3], key + 12);
	put_unaligned_le32(p->key[4], key + 16);
	put_unaligned_le32(p->key[5], key + 20);
	put_unaligned_le32(p->key[6], key + 24);
	put_unaligned_le32(p->key[7], key + 28);
	up_read(&p->lock);
}
