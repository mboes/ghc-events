{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeSynonymInstances #-}

module GHC.RTS.EventTypes where

import Control.Monad
import Data.Binary
import Data.ByteString (ByteString)
import qualified Data.ByteString.Builder as BB
import Prelude hiding (String)

#include <Rts.h>
#include <rts/EventLogFormat.h>

class Builder a where
  builder :: a -> BB.Builder

instance Builder Word16 where
  builder = BB.word16Dec
instance Builder Word32 where
  builder = BB.word32Dec
instance Builder Word64 where
  builder = BB.word64Dec
instance Builder ByteString where
  builder = BB.byteString

newtype EventTypeNum = EventTypeNum Word16
  deriving (Binary, Builder, Enum, Eq, Integral, Num, Ord, Real, Show)
newtype EventTypeDescLen = EventTypeDescLen Word32
  deriving (Binary, Builder, Enum, Eq, Integral, Num, Ord, Real, Show)
newtype EventTypeDesc = EventTypeDesc ByteString
  deriving (Builder, Eq, Ord, Show)
newtype EventTypeSize = EventTypeSize Word16
  deriving (Binary, Builder, Enum, Eq, Integral, Num, Ord, Real, Show)

newtype EventDescription = EventDescription ByteString
  deriving (Eq, Ord, Show)
newtype Timestamp = Timestamp Word64
  deriving (Binary, Builder, Enum, Eq, Integral, Num, Ord, Real, Show)
newtype ThreadId = ThreadId Word32
  deriving (Binary, Builder, Enum, Eq, Integral, Num, Ord, Real, Show)
newtype CapNo = CapNo Word16
  deriving (Binary, Builder, Enum, Eq, Integral, Num, Ord, Real, Show)
newtype Marker = Marker Word32
  deriving (Binary, Builder, Enum, Eq, Integral, Num, Ord, Real, Show)
newtype BlockSize = BlockSize Word32
  deriving (Binary, Builder, Enum, Eq, Integral, Num, Ord, Real, Show)
newtype RawThreadStopStatus = RawThreadStopStatus Word16
  deriving (Binary, Builder, Enum, Eq, Integral, Num, Ord, Real, Show)
newtype StringId = StringId Word32
  deriving (Binary, Builder, Enum, Eq, Integral, Num, Ord, Real, Show)
newtype Capset = Capset Word32
  deriving (Binary, Builder, Enum, Eq, Integral, Num, Ord, Real, Show)
newtype TaskId = TaskId Word64
  deriving (Binary, Builder, Enum, Eq, Integral, Num, Ord, Real, Show)
newtype PID = PID Word32
  deriving (Binary, Builder, Enum, Eq, Integral, Num, Ord, Real, Show)

newtype KernelThreadId = KernelThreadId { kernelThreadId :: Word64 }
  deriving (Binary, Builder, Eq, Ord, Show)

sz_event_type_num :: EventTypeSize
sz_event_type_num = 2
sz_cap :: EventTypeSize
sz_cap  = 2
sz_time :: EventTypeSize
sz_time = 8
sz_tid :: EventTypeSize
sz_tid  = 4
sz_capset :: EventTypeSize
sz_capset = 4
sz_capset_type :: EventTypeSize
sz_capset_type = 2
sz_block_size :: EventTypeSize
sz_block_size = 4
sz_block_event :: EventTypeSize
sz_block_event = sz_event_type_num + sz_time + sz_block_size + sz_time + sz_cap
sz_pid :: EventTypeSize
sz_pid = 4
sz_taskid :: EventTypeSize
sz_taskid = 8
sz_kernel_tid :: EventTypeSize
sz_kernel_tid = 8
sz_th_stop_status :: EventTypeSize
sz_th_stop_status = 2
sz_string_id :: EventTypeSize
sz_string_id = 4

{-
 - Data type delcarations to build the GHC RTS data format,
 - which is a (header, data) pair.
 -
 - Header contains EventTypes.
 - Data contains Events.
 -}
data EventLog =
  EventLog {
    header :: Header,
    dat    :: Data
  } deriving Show

newtype Header = Header {
     eventTypes :: [EventType]
  } deriving (Show, Eq)

data Data = Data {
     events :: [Event]
  } deriving Show

data EventType =
  EventType {
    num  :: EventTypeNum,
    desc :: EventTypeDesc,
    size :: Maybe EventTypeSize -- ^ 'Nothing' indicates variable size
  } deriving (Show, Eq)

data Event =
  Event {
    evTime  :: {-# UNPACK #-}!Timestamp,
    evSpec  :: EventInfo,
    evCap :: Maybe Int
  } deriving Show

data EventInfo

  -- pseudo events
  = EventBlock         { end_time   :: Timestamp,
                         cap        :: Int,
                         block_size :: BlockSize
                       }
  | UnknownEvent       { ref  :: {-# UNPACK #-}!EventTypeNum }

  -- thread scheduling
  | CreateThread       { thread :: {-# UNPACK #-}!ThreadId
                       }
  | RunThread          { thread :: {-# UNPACK #-}!ThreadId
                       }
  | StopThread         { thread :: {-# UNPACK #-}!ThreadId,
                         status :: !ThreadStopStatus
                       }
  | ThreadRunnable     { thread :: {-# UNPACK #-}!ThreadId
                       }
  | MigrateThread      { thread :: {-# UNPACK #-}!ThreadId,
                         newCap :: {-# UNPACK #-}!Int
                       }
  | WakeupThread       { thread :: {-# UNPACK #-}!ThreadId,
                         otherCap :: {-# UNPACK #-}!Int
                       }
  | ThreadLabel        { thread :: {-# UNPACK #-}!ThreadId,
                         threadlabel :: ByteString
                       }

  -- par sparks
  | CreateSparkThread  { sparkThread :: {-# UNPACK #-}!ThreadId
                       }
  | SparkCounters      { sparksCreated, sparksDud, sparksOverflowed,
                         sparksConverted, sparksFizzled, sparksGCd,
                         sparksRemaining :: {-# UNPACK #-}! Word64
                       }
  | SparkCreate        { }
  | SparkDud           { }
  | SparkOverflow      { }
  | SparkRun           { }
  | SparkSteal         { victimCap :: {-# UNPACK #-}!Int }
  | SparkFizzle        { }
  | SparkGC            { }

  -- tasks
  | TaskCreate         { taskId :: TaskId,
                         cap :: {-# UNPACK #-}!Int,
                         tid :: {-# UNPACK #-}!KernelThreadId
                       }
  | TaskMigrate        { taskId :: TaskId,
                         cap :: {-# UNPACK #-}!Int,
                         new_cap :: {-# UNPACK #-}!Int
                       }
  | TaskDelete         { taskId :: TaskId }

  -- garbage collection
  | RequestSeqGC       { }
  | RequestParGC       { }
  | StartGC            { }
  | GCWork             { }
  | GCIdle             { }
  | GCDone             { }
  | EndGC              { }
  | GlobalSyncGC       { }
  | GCStatsGHC         { heapCapset   :: {-# UNPACK #-}!Capset
                       , gen          :: {-# UNPACK #-}!Int
                       , copied       :: {-# UNPACK #-}!Word64
                       , slop, frag   :: {-# UNPACK #-}!Word64
                       , parNThreads  :: {-# UNPACK #-}!Int
                       , parMaxCopied :: {-# UNPACK #-}!Word64
                       , parTotCopied :: {-# UNPACK #-}!Word64
                       }

  -- heap statistics
  | HeapAllocated      { heapCapset  :: {-# UNPACK #-}!Capset
                       , allocBytes  :: {-# UNPACK #-}!Word64
                       }
  | HeapSize           { heapCapset  :: {-# UNPACK #-}!Capset
                       , sizeBytes   :: {-# UNPACK #-}!Word64
                       }
  | HeapLive           { heapCapset  :: {-# UNPACK #-}!Capset
                       , liveBytes   :: {-# UNPACK #-}!Word64
                       }
  | HeapInfoGHC        { heapCapset    :: {-# UNPACK #-}!Capset
                       , gens          :: {-# UNPACK #-}!Int
                       , maxHeapSize   :: {-# UNPACK #-}!Word64
                       , allocAreaSize :: {-# UNPACK #-}!Word64
                       , mblockSize    :: {-# UNPACK #-}!Word64
                       , blockSize     :: {-# UNPACK #-}!Word64
                       }

  -- adjusting the number of capabilities on the fly
  | CapCreate          { cap :: {-# UNPACK #-}!Int
                       }
  | CapDelete          { cap :: {-# UNPACK #-}!Int
                       }
  | CapDisable         { cap :: {-# UNPACK #-}!Int
                       }
  | CapEnable          { cap :: {-# UNPACK #-}!Int
                       }

  -- capability sets
  | CapsetCreate       { capset     :: {-# UNPACK #-}!Capset
                       , capsetType :: CapsetType
                       }
  | CapsetDelete       { capset :: {-# UNPACK #-}!Capset
                       }
  | CapsetAssignCap    { capset :: {-# UNPACK #-}!Capset
                       , cap    :: {-# UNPACK #-}!Int
                       }
  | CapsetRemoveCap    { capset :: {-# UNPACK #-}!Capset
                       , cap    :: {-# UNPACK #-}!Int
                       }

  -- program/process info
  | RtsIdentifier      { capset :: {-# UNPACK #-}!Capset
                       , rtsident :: ByteString
                       }
  | ProgramArgs        { capset :: {-# UNPACK #-}!Capset
                       , args   :: [ByteString]
                       }
  | ProgramEnv         { capset :: {-# UNPACK #-}!Capset
                       , env    :: [ByteString]
                       }
  | OsProcessPid       { capset :: {-# UNPACK #-}!Capset
                       , pid    :: {-# UNPACK #-}!PID
                       }
  | OsProcessParentPid { capset :: {-# UNPACK #-}!Capset
                       , ppid   :: {-# UNPACK #-}!PID
                       }
  | WallClockTime      { capset :: {-# UNPACK #-}!Capset
                       , sec    :: {-# UNPACK #-}!Word64
                       , nsec   :: {-# UNPACK #-}!Word32
                       }

  -- messages
  | Message            { msg :: ByteString }
  | UserMessage        { msg :: ByteString }
  | UserMarker         { markername :: ByteString }
  deriving Show

data ThreadStopStatus
  = NoStatus
  | HeapOverflow
  | StackOverflow
  | ThreadYielding
  | ThreadBlocked
  | ThreadFinished
  | ForeignCall
  | BlockedOnMVar
  | BlockedOnMVarRead
  | BlockedOnBlackHole
  | BlockedOnBlackHoleOwnedBy {-# UNPACK #-}!ThreadId
  | BlockedOnRead
  | BlockedOnWrite
  | BlockedOnDelay
  | BlockedOnSTM
  | BlockedOnDoProc
  | BlockedOnCCall
  | BlockedOnCCall_Interruptible
  | BlockedOnMsgThrowTo
  | ThreadMigrating
  deriving (Show)

toThreadStopStatus :: RawThreadStopStatus -> ThreadStopStatus
toThreadStopStatus (#const NoStatus) = NoStatus
toThreadStopStatus (#const HeapOverflow) = HeapOverflow
toThreadStopStatus (#const StackOverflow) = StackOverflow
toThreadStopStatus (#const ThreadYielding) = ThreadYielding
toThreadStopStatus (#const ThreadBlocked) = ThreadBlocked
toThreadStopStatus (#const ThreadFinished) = ThreadFinished
toThreadStopStatus (#const THREAD_SUSPENDED_FOREIGN_CALL) = ForeignCall
toThreadStopStatus (#const BlockedOnMVar + 6) = BlockedOnMVar
toThreadStopStatus (#const BlockedOnMVarRead + 6) = BlockedOnMVarRead
toThreadStopStatus (#const BlockedOnBlackHole + 6) = BlockedOnBlackHole
toThreadStopStatus (#const BlockedOnRead + 6) = BlockedOnRead
toThreadStopStatus (#const BlockedOnWrite + 6) = BlockedOnWrite
toThreadStopStatus (#const BlockedOnDelay + 6) = BlockedOnDelay
toThreadStopStatus (#const BlockedOnSTM + 6) = BlockedOnSTM
toThreadStopStatus (#const BlockedOnDoProc + 6) = BlockedOnDoProc
toThreadStopStatus (#const BlockedOnCCall + 6) = BlockedOnCCall
toThreadStopStatus (#const BlockedOnCCall_Interruptible + 6) = BlockedOnCCall_Interruptible
toThreadStopStatus (#const BlockedOnMsgThrowTo + 6) = BlockedOnMsgThrowTo
toThreadStopStatus (#const ThreadMigrating + 6) = ThreadMigrating
toThreadStopStatus _ = error "ThreadStopStatus.toThreadStopStatus: bad argument"

fromThreadStopStatus :: ThreadStopStatus -> RawThreadStopStatus
fromThreadStopStatus NoStatus = #const NoStatus
fromThreadStopStatus HeapOverflow = #const HeapOverflow
fromThreadStopStatus StackOverflow = #const StackOverflow
fromThreadStopStatus ThreadYielding = #const ThreadYielding
fromThreadStopStatus ThreadBlocked = #const ThreadBlocked
fromThreadStopStatus ThreadFinished = #const ThreadFinished
fromThreadStopStatus ForeignCall = #const THREAD_SUSPENDED_FOREIGN_CALL
fromThreadStopStatus BlockedOnMVar = #const BlockedOnMVar + 6
fromThreadStopStatus BlockedOnMVarRead = #const BlockedOnMVarRead + 6
fromThreadStopStatus BlockedOnBlackHole = #const BlockedOnBlackHole + 6
fromThreadStopStatus (BlockedOnBlackHoleOwnedBy _) = #const BlockedOnBlackHole + 6
fromThreadStopStatus BlockedOnRead = #const BlockedOnRead + 6
fromThreadStopStatus BlockedOnWrite = #const BlockedOnWrite + 6
fromThreadStopStatus BlockedOnDelay = #const BlockedOnDelay + 6
fromThreadStopStatus BlockedOnSTM = #const BlockedOnSTM + 6
fromThreadStopStatus BlockedOnDoProc = #const BlockedOnDoProc + 6
fromThreadStopStatus BlockedOnCCall = #const BlockedOnCCall + 6
fromThreadStopStatus BlockedOnCCall_Interruptible = #const BlockedOnCCall_Interruptible + 6
fromThreadStopStatus BlockedOnMsgThrowTo = #const BlockedOnMsgThrowTo + 6
fromThreadStopStatus ThreadMigrating = #const ThreadMigrating + 6

maxThreadStopStatus :: RawThreadStopStatus
maxThreadStopStatus  = 18

data CapsetType
  = CapsetCustom
  | CapsetOsProcess
  | CapsetClockDomain
  | CapsetUnknown
 deriving Show

toCapsetType :: Word16 -> CapsetType
toCapsetType (#const CAPSET_TYPE_CUSTOM) = CapsetCustom
toCapsetType (#const CAPSET_TYPE_OSPROCESS) = CapsetOsProcess
toCapsetType (#const CAPSET_TYPE_CLOCKDOMAIN) = CapsetClockDomain
toCapsetType _ = CapsetUnknown

-- Checks if the capability is not -1 (which indicates a global eventblock), so
-- has no associated capability
mkCap :: Int -> Maybe Int
mkCap cap = do
  guard $ fromIntegral cap /= (maxBound :: Word16)
  return cap