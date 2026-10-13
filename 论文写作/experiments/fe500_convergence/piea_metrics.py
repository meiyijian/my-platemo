"""Read stored IGD+ or the source-hashed reconstruction of missing PIEA traces."""
from functools import lru_cache
from pathlib import Path
import hashlib

import numpy as np
from scipy.io import loadmat

CACHE = Path(__file__).resolve().parent / 'piea_recomputed_igdp.mat'


@lru_cache(maxsize=1)
def cache_entries():
    data = loadmat(CACHE, squeeze_me=True, struct_as_record=False)
    entries = {str(e.filename): e for e in np.atleast_1d(data['entries'])}
    for check in np.atleast_1d(data['checks']):
        if check.stock_max_error >= 1e-11 or check.stored_max_error >= 1e-11:
            raise ValueError('PIEA IGD+ reconstruction failed its reference checks')
    return entries


def read_igdp(source, metric, fe, algorithm):
    stored = np.asarray(getattr(metric, 'IGDp', []), dtype=float).ravel()
    if stored.size == fe.size:
        return stored, 'stored metric.IGDp'
    if algorithm != 'PIEA':
        raise ValueError(f'{source.name}: missing complete IGDp trajectory')
    entry = cache_entries()[source.name]
    if (entry.source_sha256 != hashlib.sha256(source.read_bytes()).hexdigest()
            or not np.array_equal(np.asarray(entry.fe).ravel(), fe)
            or entry.FE_before != 0 or entry.FE_after != 0):
        raise ValueError(f'{source.name}: reconstruction identity or FE mismatch')
    return np.asarray(entry.igdp, dtype=float).ravel(), 'saved-population reconstruction'
