// This uses code ported from "./src/shared/engine" to train magic numbers,
// I tried a fully Luau trainer, but that took almost an hour compared to C++ taking
// a couple of seconds.

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <vector>
#include <random>

using u32 = uint32_t;
using u64 = uint64_t;

static inline u32 bit_lo(int sq) { return sq < 32 ? (1u << sq)        : 0u; }
static inline u32 bit_hi(int sq) { return sq >= 32 ? (1u << (sq - 32)) : 0u; }

static inline void mul64_hi64(u32 a_hi, u32 a_lo,
                               u32 b_hi, u32 b_lo,
                               u32& out_hi, u32& out_lo)
{
    u32 a = a_hi >> 16, b = a_hi & 0xFFFF;
    u32 c = a_lo >> 16, d = a_lo & 0xFFFF;
    u32 e = b_hi >> 16, f = b_hi & 0xFFFF;
    u32 g = b_lo >> 16, h = b_lo & 0xFFFF;

    u32 p4 = d * h;
    u32 p3 = (p4 >> 16) + c * h;
    u32 p2 = p3 >> 16;
    p3 = (p3 & 0xFFFF) + d * g;
    p2 += (p3 >> 16) + b * h;
    u32 p1 = p2 >> 16;
    p2 = (p2 & 0xFFFF) + c * g;
    p1 += p2 >> 16;
    p2 = (p2 & 0xFFFF) + d * f;
    p1 += (p2 >> 16) + a*h + b*g + c*f + d*e;

    out_hi = ((p1 & 0xFFFF) << 16) | (p2 & 0xFFFF);
    out_lo = ((p3 & 0xFFFF) << 16) | (p4 & 0xFFFF);
}

static inline int magic_index(u32 occ_hi, u32 occ_lo,
                               u32 magic_hi, u32 magic_lo,
                               int bits)
{
    u32 rhi, rlo;
    mul64_hi64(occ_hi, occ_lo, magic_hi, magic_lo, rhi, rlo);

    int shift = 64 - bits;
    if (shift >= 32)
        return (int)(rhi >> (shift - 32));
    else
        return (int)((rhi << (32 - shift)) | (rlo >> shift));
}

static u32 RAY_N_LO[64],  RAY_N_HI[64];
static u32 RAY_S_LO[64],  RAY_S_HI[64];
static u32 RAY_E_LO[64],  RAY_E_HI[64];
static u32 RAY_W_LO[64],  RAY_W_HI[64];
static u32 RAY_NE_LO[64], RAY_NE_HI[64];
static u32 RAY_NW_LO[64], RAY_NW_HI[64];
static u32 RAY_SE_LO[64], RAY_SE_HI[64];
static u32 RAY_SW_LO[64], RAY_SW_HI[64];

static void build_rays()
{
    for (int sq = 0; sq < 64; ++sq) {
        int rank = sq / 8, file = sq % 8;
        RAY_N_LO[sq] = RAY_N_HI[sq] = RAY_S_LO[sq] = RAY_S_HI[sq] = 0;
        RAY_E_LO[sq] = RAY_E_HI[sq] = RAY_W_LO[sq] = RAY_W_HI[sq] = 0;
        RAY_NE_LO[sq] = RAY_NE_HI[sq] = RAY_NW_LO[sq] = RAY_NW_HI[sq] = 0;
        RAY_SE_LO[sq] = RAY_SE_HI[sq] = RAY_SW_LO[sq] = RAY_SW_HI[sq] = 0;

#define ADD(ray, s) ray##_LO[sq] |= bit_lo(s); ray##_HI[sq] |= bit_hi(s)
        for (int r=rank+1;r<=7;r++){int s=r*8+file; ADD(RAY_N,s);}
        for (int r=rank-1;r>=0;r--){int s=r*8+file; ADD(RAY_S,s);}
        for (int f=file+1;f<=7;f++){int s=rank*8+f; ADD(RAY_E,s);}
        for (int f=file-1;f>=0;f--){int s=rank*8+f; ADD(RAY_W,s);}
        for (int r=rank+1,f=file+1;r<=7&&f<=7;r++,f++){int s=r*8+f; ADD(RAY_NE,s);}
        for (int r=rank+1,f=file-1;r<=7&&f>=0;r++,f--){int s=r*8+f; ADD(RAY_NW,s);}
        for (int r=rank-1,f=file+1;r>=0&&f<=7;r--,f++){int s=r*8+f; ADD(RAY_SE,s);}
        for (int r=rank-1,f=file-1;r>=0&&f>=0;r--,f--){int s=r*8+f; ADD(RAY_SW,s);}
#undef ADD
    }
}

static inline void apply_ray(u32 rlo, u32 rhi,
                              u32 oclo, u32 ochi,
                              bool positive,
                              u32& rlo_out, u32& rhi_out)
{
    u32 blo = rlo & oclo, bhi = rhi & ochi;
    if (!blo && !bhi) { rlo_out |= rlo; rhi_out |= rhi; return; }

    int bsq;
    if (positive) {
        bsq = blo ? __builtin_ctz(blo) : 32 + __builtin_ctz(bhi);
    } else {
        bsq = bhi ? (63 - __builtin_clz(bhi)) : (31 - __builtin_clz(blo));
    }

    u32 bsq_lo = bit_lo(bsq), bsq_hi = bit_hi(bsq);
    // bsq_bit - 1 (64-bit)
    u32 s_lo, s_hi;
    if (bsq_lo) { s_lo = bsq_lo - 1; s_hi = bsq_hi; }
    else         { s_lo = 0xFFFFFFFFu; s_hi = bsq_hi - 1; }

    u32 mlo, mhi;
    if (positive) {
        mlo = bsq_lo | s_lo;
        mhi = bsq_hi | s_hi;
    } else {
        mlo = ~s_lo;
        mhi = ~s_hi;
    }
    rlo_out |= rlo & mlo;
    rhi_out |= rhi & mhi;
}

static void classical_rook_attacks(int sq, u32 ochi, u32 oclo,
                                   u32& out_hi, u32& out_lo)
{
    out_lo = out_hi = 0;
    apply_ray(RAY_N_LO[sq], RAY_N_HI[sq], oclo, ochi, true,  out_lo, out_hi);
    apply_ray(RAY_E_LO[sq], RAY_E_HI[sq], oclo, ochi, true,  out_lo, out_hi);
    apply_ray(RAY_S_LO[sq], RAY_S_HI[sq], oclo, ochi, false, out_lo, out_hi);
    apply_ray(RAY_W_LO[sq], RAY_W_HI[sq], oclo, ochi, false, out_lo, out_hi);
}

static void classical_bishop_attacks(int sq, u32 ochi, u32 oclo,
                                     u32& out_hi, u32& out_lo)
{
    out_lo = out_hi = 0;
    apply_ray(RAY_NE_LO[sq], RAY_NE_HI[sq], oclo, ochi, true,  out_lo, out_hi);
    apply_ray(RAY_NW_LO[sq], RAY_NW_HI[sq], oclo, ochi, true,  out_lo, out_hi);
    apply_ray(RAY_SE_LO[sq], RAY_SE_HI[sq], oclo, ochi, false, out_lo, out_hi);
    apply_ray(RAY_SW_LO[sq], RAY_SW_HI[sq], oclo, ochi, false, out_lo, out_hi);
}

static void make_rook_mask(int sq, u32& mhi, u32& mlo)
{
    int rank = sq / 8, file = sq % 8;
    mlo = mhi = 0;
    for (int r=rank+1;r<=6;r++){int s=r*8+file; mlo|=bit_lo(s); mhi|=bit_hi(s);}
    for (int r=rank-1;r>=1;r--){int s=r*8+file; mlo|=bit_lo(s); mhi|=bit_hi(s);}
    for (int f=file+1;f<=6;f++){int s=rank*8+f; mlo|=bit_lo(s); mhi|=bit_hi(s);}
    for (int f=file-1;f>=1;f--){int s=rank*8+f; mlo|=bit_lo(s); mhi|=bit_hi(s);}
}

static void make_bishop_mask(int sq, u32& mhi, u32& mlo)
{
    int rank = sq / 8, file = sq % 8;
    mlo = mhi = 0;
    for (int r=rank+1,f=file+1;r<=6&&f<=6;r++,f++){int s=r*8+f; mlo|=bit_lo(s); mhi|=bit_hi(s);}
    for (int r=rank+1,f=file-1;r<=6&&f>=1;r++,f--){int s=r*8+f; mlo|=bit_lo(s); mhi|=bit_hi(s);}
    for (int r=rank-1,f=file+1;r>=1&&f<=6;r--,f++){int s=r*8+f; mlo|=bit_lo(s); mhi|=bit_hi(s);}
    for (int r=rank-1,f=file-1;r>=1&&f>=1;r--,f--){int s=r*8+f; mlo|=bit_lo(s); mhi|=bit_hi(s);}
}

struct SubsetIter {
    u64 mask, sub;
    bool first;
    SubsetIter(u32 mhi, u32 mlo)
        : mask((u64)mhi << 32 | mlo), sub(0), first(true) {}
    bool next(u32& lo, u32& hi) {
        if (!first && sub == 0) return false;
        first = false;
        lo = (u32)sub; hi = (u32)(sub >> 32);
        sub = (sub - mask) & mask;
        return true;
    }
};

static int score_magic(int sq, int bits,
                       u32 magic_hi, u32 magic_lo,
                       u32 mask_hi, u32 mask_lo,
                       bool is_rook)
{
    int table_size = 1 << bits;

    // Thread-local generation-stamped scratch tables
    static thread_local std::vector<u32> seen_hi, seen_lo, seen_gen;
    static thread_local u32 cur_gen = 0;

    if ((int)seen_hi.size() < table_size) {
        seen_hi.assign(table_size, 0);
        seen_lo.assign(table_size, 0);
        seen_gen.assign(table_size, 0);
    }

    ++cur_gen;
    u32 gen = cur_gen;
    int collisions = 0;

    SubsetIter it(mask_hi, mask_lo);
    u32 olo, ohi;
    while (it.next(olo, ohi)) {
        int idx = magic_index(ohi, olo, magic_hi, magic_lo, bits);

        u32 ahi, alo;
        if (is_rook) classical_rook_attacks(sq, ohi, olo, ahi, alo);
        else         classical_bishop_attacks(sq, ohi, olo, ahi, alo);

        if (seen_gen[idx] == gen) {
            if (seen_hi[idx] != ahi || seen_lo[idx] != alo)
                ++collisions;
        } else {
            seen_gen[idx] = gen;
            seen_hi[idx]  = ahi;
            seen_lo[idx]  = alo;
        }
    }
    return collisions;
}

struct SparseRng {
    std::mt19937_64 rng;
    SparseRng() : rng(std::random_device{}()) {}

    void sparse(u32& hi, u32& lo) {
        u64 v = rng() & rng() & rng();
        hi = (u32)(v >> 32);
        lo = (u32)v;
    }
    int randint(int lo_val, int hi_val) {
        return (int)(rng() % (u64)(hi_val - lo_val + 1)) + lo_val;
    }
};

static const int ROOK_BITS[64] = {
    12,11,11,11,11,11,11,12,
    11,10,10,10,10,10,10,11,
    11,10,10,10,10,10,10,11,
    11,10,10,10,10,10,10,11,
    11,10,10,10,10,10,10,11,
    11,10,10,10,10,10,10,11,
    11,10,10,10,10,10,10,11,
    12,11,11,11,11,11,11,12,
};
static const int BISHOP_BITS[64] = {
    6,5,5,5,5,5,5,6,
    5,5,5,5,5,5,5,5,
    5,5,7,7,7,7,5,5,
    5,5,7,9,9,7,5,5,
    5,5,7,9,9,7,5,5,
    5,5,7,7,7,7,5,5,
    5,5,5,5,5,5,5,5,
    6,5,5,5,5,5,5,6,
};

static u32 ROOK_MAGIC_HI[64] = {
    0x00800010,0x00400010,0x00800810,0x00800408,0x00800204,0x00800102,0x00800080,0x00800020,
    0x00008000,0x00004000,0x00008010,0x00008008,0x00008004,0x00008002,0x00008001,0x00008004,
    0x00002080,0x00004040,0x00008080,0x00008080,0x00008080,0x00008080,0x00000101,0x00000200,
    0x00002080,0x00002000,0x00001000,0x00000800,0x00000400,0x00000200,0x00000100,0x00008000,
    0x00002040,0x00002000,0x00001000,0x00000800,0x00000400,0x00000200,0x00000200,0x00008000,
    0x00002040,0x00002000,0x00001000,0x00000800,0x00000400,0x00000200,0x00000100,0x00000040,
    0x00002040,0x00002000,0x00001000,0x00000800,0x00000400,0x00000200,0x00008001,0x00008004,
    0x00001020,0x00001020,0x00000810,0x00000408,0x00010002,0x00010002,0x00010000,0x00000020,
};
static u32 ROOK_MAGIC_LO[64] = {
    0x20400080,0x00200040,0x00200080,0x00100080,0x00080080,0x00040080,0x01000200,0x40800100,
    0x20400080,0x20005000,0x00200080,0x00100080,0x00080080,0x00040080,0x00020080,0x40800100,
    0x00400080,0x00201000,0x10002000,0x08001000,0x04000800,0x02000400,0x00020004,0x00408104,
    0x80004000,0x40005000,0x80200080,0x80100080,0x40008080,0x20004080,0x80800200,0x80004100,
    0x00800080,0x00404010,0x00808020,0x00808010,0x00808008,0x00808004,0x01010004,0x40800100,
    0x00808000,0x00400080,0x00200080,0x00100080,0x00080080,0x00040080,0x00020080,0x08102004,
    0x00800080,0x00400080,0x00200080,0x00100080,0x00080080,0x00040080,0x00020080,0x41000080,
    0x40800101,0x40008101,0x20004101,0x10002101,0x04080011,0x04000801,0x82000401,0x40810402,
};
static u32 BISHOP_MAGIC_HI[64] = {
    0x00000202,0x00000202,0x00000401,0x00000404,0x00000110,0x00000082,0x00000041,0x00000010,
    0x00000004,0x00000002,0x00000004,0x00000004,0x00000001,0x00000000,0x00000000,0x00000020,
    0x00040008,0x00020004,0x00010002,0x00008008,0x00008004,0x00002001,0x00004000,0x00002000,
    0x00020800,0x00010400,0x00002080,0x00004040,0x00008400,0x00004040,0x00008080,0x00004040,
    0x00010410,0x00008208,0x00001044,0x00000200,0x00004040,0x00008081,0x00010101,0x00008080,
    0x00008208,0x00004104,0x00000820,0x00000020,0x00000801,0x00010101,0x00020202,0x00010101,
    0x00004104,0x00002082,0x00000020,0x00000000,0x00000010,0x00000404,0x00040404,0x00020202,
    0x00001041,0x00000020,0x00000000,0x00000000,0x00000001,0x00000004,0x00000404,0x00020202,
};
static u32 BISHOP_MAGIC_LO[64] = {
    0x02020200,0x02020200,0x02020000,0x00400800,0x00004000,0x10400000,0x04104000,0x04104100,
    0x04040400,0x02020200,0x01020200,0x00400800,0x40400000,0x21040000,0x04104100,0x08208200,
    0x08080800,0x04040400,0x01010400,0x01010000,0x00080000,0x00884000,0x82082000,0x41041000,
    0x10101000,0x08080800,0x04010400,0x04010200,0x00080200,0x02011000,0x01041000,0x00820800,
    0x00202000,0x00101000,0x00080800,0x00008080,0x04040100,0x00020100,0x00020800,0x00010400,
    0x20004000,0x10002000,0x08801000,0x11000800,0x00400400,0x01000200,0x02000400,0x01000200,
    0x10400000,0x08208200,0x08410000,0x20880000,0x02020000,0x04080200,0x04040400,0x02020200,
    0x04104100,0x08208200,0x20841000,0x00208800,0x10020200,0x04080200,0x04040400,0x02020200,
};

struct Entry {
    int  sq;
    int  bits;
    bool is_rook;
    u32  mask_hi, mask_lo;
    u32  magic_hi, magic_lo;
    int  collisions;
};
static const char* SQ_NAMES[64] = {
    "a1","b1","c1","d1","e1","f1","g1","h1",
    "a2","b2","c2","d2","e2","f2","g2","h2",
    "a3","b3","c3","d3","e3","f3","g3","h3",
    "a4","b4","c4","d4","e4","f4","g4","h4",
    "a5","b5","c5","d5","e5","f5","g5","h5",
    "a6","b6","c6","d6","e6","f6","g6","h6",
    "a7","b7","c7","d7","e7","f7","g7","h7",
    "a8","b8","c8","d8","e8","f8","g8","h8",
};

static void print_report(long long iter,
                         const std::vector<Entry>& state,
                         long long grand_collisions)
{
    long long grand_total = 0;
    const Entry* worst = nullptr;
    for (auto& e : state) {
        grand_total += 1LL << e.bits;
        if (!worst || e.collisions > worst->collisions) worst = &e;
    }
    double pct = (double)grand_collisions / (double)grand_total * 100.0;
    printf("iter %-10lld | collisions: %-6lld | %.6f%%\n",
           iter, grand_collisions, pct);
    if (worst && worst->collisions > 0)
        printf("  worst: %s %s — %d collisions\n",
               worst->is_rook ? "rook" : "bishop",
               SQ_NAMES[worst->sq], worst->collisions);
    fflush(stdout);
}

static void print_magics(const std::vector<Entry>& state)
{
    printf("\n=== Trained magic numbers ===\n");
    for (int pass = 0; pass < 2; ++pass) {
        bool rook = (pass == 0);
        printf("\n-- %s\nhi = {", rook ? "rook" : "bishop");
        bool sep = false;
        for (auto& e : state) {
            if (e.is_rook != rook) continue;
            if (sep) printf(",");
            sep = true;
            printf("0x%08X", e.magic_hi);
        }
        printf("\n},\nlo = {");
        sep = false;
        for (auto& e : state) {
            if (e.is_rook != rook) continue;
            if (sep) printf(",");
            sep = true;
            printf("0x%08X", e.magic_lo);
        }
        printf("\n},\n");
    }
}

int main()
{
    build_rays();

    SparseRng rng;
    std::vector<Entry> state;
    state.reserve(128);
    long long grand_collisions = 0;

    auto add_entries = [&](bool is_rook) {
        const int* bits_arr    = is_rook ? ROOK_BITS    : BISHOP_BITS;
        u32*       magic_hi_arr = is_rook ? ROOK_MAGIC_HI : BISHOP_MAGIC_HI;
        u32*       magic_lo_arr = is_rook ? ROOK_MAGIC_LO : BISHOP_MAGIC_LO;

        for (int sq = 0; sq < 64; ++sq) {
            Entry e;
            e.sq      = sq;
            e.bits    = bits_arr[sq];
            e.is_rook = is_rook;
            if (is_rook) make_rook_mask(sq, e.mask_hi, e.mask_lo);
            else         make_bishop_mask(sq, e.mask_hi, e.mask_lo);
            e.magic_hi   = magic_hi_arr[sq];
            e.magic_lo   = magic_lo_arr[sq];
            e.collisions = score_magic(sq, e.bits,
                                       e.magic_hi, e.magic_lo,
                                       e.mask_hi, e.mask_lo, is_rook);
            grand_collisions += e.collisions;
            state.push_back(e);
        }
    };

    add_entries(true);   // rooks
    add_entries(false);  // bishops

    // Dirty list: indices into state[] that still have collisions
    std::vector<int> dirty_list;
    for (int i = 0; i < (int)state.size(); ++i)
        if (state[i].collisions > 0)
            dirty_list.push_back(i);

    printf("Starting training...\n");
    printf("Initial collisions: %lld  (dirty squares: %zu)\n\n",
           grand_collisions, dirty_list.size());
    fflush(stdout);

    if (grand_collisions == 0) {
        printf("Already collision-free!\n");
        print_magics(state);
        return 0;
    }

    const long long REPORT_EVERY = 10000;
    long long iteration = 0;

    while (grand_collisions > 0) {
        ++iteration;

        // Pick a random dirty entry
        int pick_idx = rng.randint(0, (int)dirty_list.size() - 1);
        int si       = dirty_list[pick_idx];
        Entry& e     = state[si];

        u32 new_hi, new_lo;
        rng.sparse(new_hi, new_lo);
        int new_col = score_magic(e.sq, e.bits, new_hi, new_lo,
                                  e.mask_hi, e.mask_lo, e.is_rook);

        if (new_col < e.collisions) {
            grand_collisions -= (e.collisions - new_col);
            e.magic_hi   = new_hi;
            e.magic_lo   = new_lo;
            e.collisions = new_col;

            if (new_col == 0) {
                // O(1) swap-remove from dirty_list
                dirty_list[pick_idx] = dirty_list.back();
                dirty_list.pop_back();
            }
        }

        if (iteration % REPORT_EVERY == 0)
            print_report(iteration, state, grand_collisions);
    }

    print_report(iteration, state, grand_collisions);
    printf("\nTraining complete after %lld iterations!\n", iteration);
    print_magics(state);
    return 0;
}
