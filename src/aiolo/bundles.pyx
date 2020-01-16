# cython: language_level=3

from typing import Iterable

from . import exceptions, logs, typedefs
from . cimport lo, messages, paths, timetags


cdef class Bundle:
    def __cinit__(
        self,
        msgs: Iterable[typedefs.BundleTypes],
        timetag: typedefs.TimeTagTypes = None
    ):
        self.timetag = timetag if isinstance(timetag, timetags.TimeTag) else timetags.TimeTag(timetag)
        self.lo_bundle = lo.lo_bundle_new((<timetags.TimeTag>timetag).lo_timetag)
        if self.lo_bundle is NULL:
            raise MemoryError
        self.msgs = []
        for msg in msgs:
            self.add(msg)

    def __init__(
        self,
        msgs: Iterable[typedefs.BundleTypes],
        timetag: typedefs.TimeTagTypes = None
    ):
        pass

    def __dealloc__(self):
        lo.lo_bundle_free(self.lo_bundle)

    def __repr__(self):
        return 'Bundle(%r, %r)' % (self.msgs, self.timetag)

    def __iand__(self, other: typedefs.BundleTypes):
        return self.add(other)

    def __iadd__(self, other: typedefs.BundleTypes):
        return self.add(other)

    cpdef object add(Bundle self, msg: typedefs.BundleTypes):
        if isinstance(msg, messages.Message):
            self.add_message(msg)
        elif isinstance(msg, Bundle):
            self.add_bundle(msg)
        else:
            raise ValueError('Cannot add %s to bundle' % repr(msg))
        return self

    cpdef object add_message(Bundle self, messages.Message message):
        if lo.lo_bundle_add_message(
            self.lo_bundle,
            (<paths.Path>message.route.path).charp(),
            (<messages.Message>message).lo_message
        ) != 0:
            raise MemoryError
        self.msgs.append(message)
        return None

    cpdef object add_bundle(Bundle self, Bundle bundle):
        if lo.lo_bundle_add_bundle(self.lo_bundle, bundle.lo_bundle) != 0:
            raise MemoryError
        self.msgs.append(bundle)
        return None

    cdef object send(self, lo.lo_address lo_address):
        logs.logger.debug('%r: publishing %r', self)
        count = lo.lo_send_bundle(lo_address, self.lo_bundle)
        if count <= 0:
            raise exceptions.SendError(count)
        logs.logger.debug('%r: sent %s bytes', self, count)
        return count
