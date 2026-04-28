#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <vector>
#include <random>

using u64 = uint64_t;

static inline int magic_index(u64 occ, u64 magic, int bits) {
    return (int)((occ * magic) >> (64 - bits));
}

static u64 RAY_N[64], RAY_S[64], RAY_E[64], RAY_W[64];
static u64 RAY_NE[64], RAY_NW[64], RAY_SE[64], RAY_SW[64];

static void build_rays() {
    for (int sq = 0; sq < 64; ++sq) {
        int rank = sq / 8, file = sq % 8;
        RAY_N[sq] = RAY_S[sq] = RAY_E[sq] = RAY_W[sq] = 0;
        RAY_NE[sq] = RAY_NW[sq] = RAY_SE[sq] = RAY_SW[sq] = 0;

        for (int r = rank + 1; r <= 7; r++) RAY_N[sq] |= (1ULL << (r * 8 + file));
        for (int r = rank - 1; r >= 0; r--) RAY_S[sq] |= (1ULL << (r * 8 + file));
        for (int f = file + 1; f <= 7; f++) RAY_E[sq] |= (1ULL << (rank * 8 + f));
        for (int f = file - 1; f >= 0; f--) RAY_W[sq] |= (1ULL << (rank * 8 + f));
        for (int r = rank + 1, f = file + 1; r <= 7 && f <= 7; r++, f++) RAY_NE[sq] |= (1ULL << (r * 8 + f));
        for (int r = rank + 1, f = file - 1; r <= 7 && f >= 0; r++, f--) RAY_NW[sq] |= (1ULL << (r * 8 + f));
        for (int r = rank - 1, f = file + 1; r >= 0 && f <= 7; r--, f++) RAY_SE[sq] |= (1ULL << (r * 8 + f));
        for (int r = rank - 1, f = file - 1; r >= 0 && f >= 0; r--, f--) RAY_SW[sq] |= (1ULL << (r * 8 + f));
    }
}

static inline u64 get_attacks(u64 ray, u64 occ, bool positive) {
    u64 blockers = ray & occ;
    if (!blockers) return ray;
    int bsq = positive ? __builtin_ctzll(blockers) : 63 - __builtin_clzll(blockers);
    u64 mask = (1ULL << bsq);
    if (positive) mask |= (mask - 1);
    else mask = ~(mask - 1);
    return ray & mask;
}

static u64 classical_rook_attacks(int sq, u64 occ) {
    return get_attacks(RAY_N[sq], occ, true) | get_attacks(RAY_E[sq], occ, true) |
           get_attacks(RAY_S[sq], occ, false) | get_attacks(RAY_W[sq], occ, false);
}

static u64 classical_bishop_attacks(int sq, u64 occ) {
    return get_attacks(RAY_NE[sq], occ, true) | get_attacks(RAY_NW[sq], occ, true) |
           get_attacks(RAY_SE[sq], occ, false) | get_attacks(RAY_SW[sq], occ, false);
}

static u64 make_rook_mask(int sq) {
    int rank = sq / 8, file = sq % 8;
    u64 m = 0;
    for (int r = rank + 1; r <= 6; r++) m |= (1ULL << (r * 8 + file));
    for (int r = rank - 1; r >= 1; r--) m |= (1ULL << (r * 8 + file));
    for (int f = file + 1; f <= 6; f++) m |= (1ULL << (rank * 8 + f));
    for (int f = file - 1; f >= 1; f--) m |= (1ULL << (rank * 8 + f));
    return m;
}

static u64 make_bishop_mask(int sq) {
    int rank = sq / 8, file = sq % 8;
    u64 m = 0;
    for (int r = rank + 1, f = file + 1; r <= 6 && f <= 6; r++, f++) m |= (1ULL << (r * 8 + f));
    for (int r = rank + 1, f = file - 1; r <= 6 && f >= 1; r++, f--) m |= (1ULL << (r * 8 + f));
    for (int r = rank - 1, f = file + 1; r >= 1 && f <= 6; r--, f++) m |= (1ULL << (r * 8 + f));
    for (int r = rank - 1, f = file - 1; r >= 1 && f >= 1; r--, f--) m |= (1ULL << (r * 8 + f));
    return m;
}

struct SubsetIter {
    u64 mask, sub;
    bool first;
    SubsetIter(u64 m) : mask(m), sub(0), first(true) {}
    bool next(u64& out) {
        if (!first && sub == 0) return false;
        first = false;
        out = sub;
        sub = (sub - mask) & mask;
        return true;
    }
};

static int score_magic(int sq, int bits, u64 magic, u64 mask, bool is_rook) {
    int table_size = 1 << bits;
    static thread_local std::vector<u64> seen_att, seen_gen;
    static thread_local unsigned int cur_gen = 0;
    if ((int)seen_att.size() < table_size) {
        seen_att.assign(table_size, 0);
        seen_gen.assign(table_size, 0);
    }
    ++cur_gen;
    unsigned int gen = cur_gen;
    int collisions = 0;
    SubsetIter it(mask);
    u64 occ;
    while (it.next(occ)) {
        int idx = magic_index(occ, magic, bits);
        u64 att = is_rook ? classical_rook_attacks(sq, occ) : classical_bishop_attacks(sq, occ);
        if (seen_gen[idx] == gen) {
            if (seen_att[idx] != att) ++collisions;
        } else {
            seen_gen[idx] = gen;
            seen_att[idx] = att;
        }
    }
    return collisions;
}

struct SparseRng {
    std::mt19937_64 rng;
    SparseRng() : rng(std::random_device{}()) {}
    u64 sparse() { return rng() & rng() & rng(); }
    int randint(int lo, int hi) { return (int)(rng() % (u64)(hi - lo + 1)) + lo; }
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

struct Entry {
    int sq;
    int bits;
    bool is_rook;
    u64 mask;
    u64 magic;
    int collisions;
};

static void print_magics(const std::vector<Entry>& state) {
    printf("\n=== Trained magic numbers ===\n");
    for (int pass = 0; pass < 2; ++pass) {
        bool rook = (pass == 0);
        printf("\n-- %s\nmagics = {\n\t", rook ? "rook" : "bishop");
        bool sep = false;
        int count = 0;
        for (auto& e : state) {
            if (e.is_rook != rook) continue;
            if (sep) printf(",");
            if (count > 0 && count % 4 == 0) printf("\n\t");
            sep = true;
            printf("0x%016llXi", (unsigned long long)e.magic);
            count++;
        }
        printf("\n},\n");
    }
}

int main() {
    build_rays();
    SparseRng rng;
    std::vector<Entry> state;
    long long grand_collisions = 0;
    auto add_entries = [&](bool is_rook) {
        const int* bits_arr = is_rook ? ROOK_BITS : BISHOP_BITS;
        for (int sq = 0; sq < 64; ++sq) {
            Entry e;
            e.sq = sq;
            e.bits = bits_arr[sq];
            e.is_rook = is_rook;
            e.mask = is_rook ? make_rook_mask(sq) : make_bishop_mask(sq);
            e.magic = 0;
            e.collisions = 1; // start with 1 to force training
            state.push_back(e);
        }
    };
    add_entries(true); add_entries(false);
    std::vector<int> dirty_list;
    for (int i = 0; i < (int)state.size(); ++i) dirty_list.push_back(i);

    while (!dirty_list.empty()) {
        int pick_idx = rng.randint(0, (int)dirty_list.size() - 1);
        int si = dirty_list[pick_idx];
        Entry& e = state[si];
        u64 new_magic = rng.sparse();
        int new_col = score_magic(e.sq, e.bits, new_magic, e.mask, e.is_rook);
        if (new_col == 0) {
            e.magic = new_magic;
            e.collisions = 0;
            dirty_list[pick_idx] = dirty_list.back();
            dirty_list.pop_back();
            printf("Found magic for %s %d\n", e.is_rook ? "rook" : "bishop", e.sq);
        }
    }
    print_magics(state);
    return 0;
}
