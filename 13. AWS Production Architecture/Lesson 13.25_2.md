# AWS Masterclass — Lesson 25 Part 2

# EBS Performance Engineering, Sizing & Troubleshooting

Now we answer one of the most important real-world questions:

> **“My application is slow. Is the problem EC2 CPU, EBS IOPS, EBS throughput, latency, queue depth, filesystem, or the instance’s EBS bandwidth?”**

A production engineer should never immediately say:

```text
"Increase the disk."
```

or:

```text
"Upgrade EC2."
```

We first identify **which layer is saturated**.

---

# 1. The Complete EBS Performance Path

Your application does not communicate directly with some magical “disk.”

The path is:

```text
Application
    │
    ▼
Database / runtime
    │
    ▼
Filesystem
    │
    ▼
Linux block layer
    │
    ▼
NVMe driver
    │
    ▼
EC2 instance EBS bandwidth
    │
    ▼
EBS volume
    │
    ▼
AWS storage infrastructure
```

Therefore the effective performance is roughly:

```text
Effective Storage Performance
=
minimum capability of all relevant layers
```

Example:

```text
EBS volume:
20,000 IOPS capable

EC2 instance:
10,000 IOPS capable

Application:

      ↓

Maximum practical result
≈ 10,000 IOPS
```

AWS specifically warns that an EC2 instance's EBS limits can become the bottleneck even when the attached volume is provisioned for more performance. ([AWS Documentation][1])

---

# 2. The Four Storage Numbers

Before doing anything else, remember these four:

```text
IOPS
Throughput
Latency
Queue Depth
```

They answer different questions.

| Metric      | Question                                     |
| ----------- | -------------------------------------------- |
| IOPS        | How many I/O operations per second?          |
| Throughput  | How much data per second?                    |
| Latency     | How long does one I/O take?                  |
| Queue depth | How many I/O requests are waiting/in flight? |

They influence one another, but they are **not interchangeable**.

---

# 3. IOPS

IOPS:

```text
Input / Output Operations Per Second
```

Imagine a database performing:

```text
read 16 KiB
write 16 KiB
read 8 KiB
write 4 KiB
read 16 KiB
```

If it performs:

```text
5,000 operations every second
```

then approximately:

```text
5,000 IOPS
```

This is especially important for:

```text
OLTP databases
database indexes
transaction logs
small random reads/writes
metadata-heavy applications
```

---

# 4. Throughput

Throughput measures:

```text
data transferred / second
```

Usually discussed as:

```text
MiB/s
```

Suppose:

```text
250 MiB
```

is transferred every second.

Then:

```text
Throughput = 250 MiB/s
```

Common throughput-heavy workloads include:

```text
ETL
large file processing
analytics
large sequential reads
logs
backup/restore
```

---

# 5. The Most Important Storage Formula

For simplified capacity planning:

```text
Throughput
≈
IOPS × I/O size
```

Make sure the units are converted properly.

Example:

```text
IOPS     = 3,000
I/O size = 16 KiB
```

Then:

```text
3,000 × 16 KiB

= 48,000 KiB/s

÷ 1024

≈ 46.9 MiB/s
```

So:

```text
3,000 IOPS
does NOT automatically mean
huge throughput.
```

---

# 6. Same IOPS, Different Throughput

Consider:

```text
3,000 IOPS
```

### 4 KiB operations

```text
3,000 × 4 KiB
≈ 11.7 MiB/s
```

### 16 KiB operations

```text
3,000 × 16 KiB
≈ 46.9 MiB/s
```

### 64 KiB operations

```text
3,000 × 64 KiB
≈ 187.5 MiB/s
```

### 256 KiB operations

```text
3,000 × 256 KiB
≈ 750 MiB/s
```

But this does **not** mean a 3,000-IOPS volume can necessarily deliver 750 MiB/s.

Why?

Because:

```text
Throughput limit
```

may be reached first.

AWS documents this exact relationship: large I/O sizes can hit the volume's throughput ceiling before hitting its IOPS ceiling. ([AWS Documentation][1])

---

# 7. Think of Two Ceilings

A volume effectively has multiple limits:

```text
        Workload
           │
           ▼
      ┌──────────┐
      │ IOPS cap │
      └────┬─────┘
           │
      ┌────▼──────────┐
      │ Throughput cap│
      └────┬──────────┘
           │
           ▼
        Result
```

Example:

```text
gp3

IOPS provisioned:
3,000

Throughput provisioned:
125 MiB/s
```

Application issues:

```text
3,000 × 64 KiB
≈ 187.5 MiB/s demand
```

But the volume is configured for:

```text
125 MiB/s
```

Therefore:

```text
Throughput becomes the bottleneck
```

before 3,000 64-KiB operations can be sustained.

---

# 8. Current gp3 Performance Model

As of the current AWS EBS generation, a normal `gp3` volume includes:

```text
3,000 IOPS
125 MiB/s
```

and does **not use burst credits**; provisioned gp3 performance can be sustained continuously. Current AWS limits allow provisioning up to **80,000 IOPS** and **2,000 MiB/s**, subject to size and IOPS/throughput ratios. ([AWS Documentation][2])

Mental model:

```text
gp3
 │
 ├── Capacity
 │
 ├── IOPS
 │
 └── Throughput
```

These can largely be tuned independently.

---

# 9. Why gp3 Is Easier to Operate

Suppose:

```text
Volume size:
100 GiB

Needed:
8,000 IOPS
250 MiB/s
```

With gp3 you can conceptually provision:

```text
Size       = 100 GiB
IOPS       = 8,000
Throughput = 250 MiB/s
```

You don't need to enlarge the disk merely because you need more IOPS.

That is a major difference from `gp2`.

---

# 10. The Old gp2 Model

With `gp2`:

```text
performance depends heavily
on volume size
```

The current documented baseline is approximately:

```text
3 IOPS per GiB
```

with a minimum of 100 baseline IOPS and maximum baseline performance of 16,000 IOPS. Smaller gp2 volumes below 1 TiB can burst up to 3,000 IOPS using I/O credits. ([AWS Documentation][2])

Example:

```text
100 GiB gp2
```

Baseline:

```text
100 × 3

= 300 IOPS
```

But it can temporarily burst toward:

```text
3,000 IOPS
```

while burst credits remain.

---

# 11. gp2 Burst Credits

Imagine:

```text
100 GiB gp2

Baseline:
300 IOPS

Workload:
3,000 IOPS
```

The volume is consuming credits because:

```text
demand > baseline
```

Consumption above baseline:

```text
3,000 - 300

= 2,700 credits/sec
```

AWS gives gp2 volumes a maximum I/O credit bucket of 5.4 million credits. A 100-GiB volume can therefore sustain the full 3,000-IOPS burst for around 2,000 seconds — roughly 33 minutes — from a full bucket. ([AWS Documentation][2])

Then the workload may suddenly behave more like:

```text
Before:

3000 IOPS
████████████████████


credits empty


After:

300 IOPS
██
```

And the application becomes slow.

---

# 12. Classic gp2 Production Incident

Monday morning:

```text
Application:
FAST
```

30 minutes into heavy traffic:

```text
Application:
SLOW
```

CPU:

```text
30%
```

Memory:

```text
normal
```

Network:

```text
normal
```

Engineer restarts the application.

It appears fine again later.

But the real problem could be:

```text
gp2 BurstBalance
      ↓
100%
      ↓
60%
      ↓
20%
      ↓
0%
```

`BurstBalance` specifically reports the percentage of burst credits remaining for gp2, st1, and sc1 volumes. ([AWS Documentation][3])

---

# 13. Why gp3 Usually Removes This Problem

gp3 doesn't operate using that gp2 burst-credit model.

If configured:

```text
3,000 IOPS
```

the design expectation is sustained provisioned performance, rather than:

```text
300 baseline
+
temporary burst to 3000
```

AWS explicitly states that gp3 doesn't use burst performance and can sustain its provisioned IOPS and throughput indefinitely. ([AWS Documentation][2])

---

# 14. gp2 → gp3 Migration

A very common cost/performance modernization is:

```text
gp2
 ↓
gp3
```

AWS Elastic Volumes supports changing an existing volume type and tuning IOPS/throughput without detaching the volume or restarting supported instances. ([AWS Documentation][2])

Example:

```bash
aws ec2 modify-volume \
  --volume-id vol-0123456789abcdef0 \
  --volume-type gp3 \
  --iops 3000 \
  --throughput 125 \
  --region ap-south-1
```

Check modification:

```bash
aws ec2 describe-volumes-modifications \
  --volume-ids vol-0123456789abcdef0 \
  --region ap-south-1
```

Possible lifecycle:

```text
modifying
   ↓
optimizing
   ↓
completed
```

---

# 15. Important gp2 Migration Mistake

Suppose your existing gp2 disk is:

```text
2 TiB
```

gp2 baseline:

```text
2048 × 3

≈ 6,144 IOPS
```

Now someone blindly migrates to gp3:

```text
gp3 default
3,000 IOPS
```

Congratulations:

```text
you just reduced storage performance
```

even though you moved to a newer volume type.

Therefore migration workflow should be:

```text
Measure current workload
       ↓
understand existing gp2 entitlement
       ↓
determine actual required IOPS
       ↓
determine throughput
       ↓
configure gp3
       ↓
monitor
```

Not:

```text
gp2 → gp3
because internet said gp3 is better
```

---

# 16. io2 Block Express

Now suppose you truly need high-end transactional storage.

Current `io2` Block Express supports up to:

```text
256,000 IOPS
4,000 MiB/s
64 TiB
```

and AWS documents average latency below 500 microseconds for 16-KiB I/O when used with suitable Nitro-based instances. As of April 30, 2025, AWS says all io2 volumes use Block Express. ([AWS Documentation][4])

That is a very different performance class from:

```text
ordinary web server root disk
```

---

# 17. Don't Use io2 Because It Sounds Fast

Example workload:

```text
Node.js API

100 GiB disk

actual peak:
700 IOPS
20 MiB/s
```

Using:

```text
io2 50,000 IOPS
```

would likely just be expensive overengineering.

Correct design:

```text
Observe actual requirement
        ↓
provide headroom
        ↓
choose appropriate volume
```

For many general-purpose workloads:

```text
gp3
```

is the better starting point.

---

# 18. Latency

Latency is:

```text
time from sending I/O request
until completion acknowledgement
```

AWS defines EBS latency as the end-to-end client time of an I/O request. ([AWS Documentation][1])

Example:

```text
Query requires:

100 storage operations

Each averages:
1 ms
```

Storage contribution might roughly be:

```text
100 × 1 ms
```

depending on concurrency and application behavior.

Now imagine:

```text
latency rises to 15 ms
```

Even with CPU idle, your application can feel extremely slow.

---

# 19. Queue Depth

Queue depth:

```text
number of pending I/O requests
waiting to complete
```

Think of a supermarket:

```text
Storage device
=
cashier

I/O requests
=
customers
```

Healthy:

```text
Customer → cashier
Customer → cashier
```

Overloaded:

```text
Customer
Customer
Customer
Customer
Customer
Customer
   ↓
Cashier
```

Queue growing means:

```text
requests arriving
faster than they are being completed
```

AWS recommends roughly one outstanding I/O per 1,000 available IOPS as a starting point for SSD-backed EBS performance tuning, while emphasizing that optimal queue depth depends on the workload. ([AWS Documentation][1])

So:

```text
3,000 provisioned IOPS

rough starting queue depth
≈ 3
```

Not a universal alarm threshold—just a tuning guideline.

---

# 20. Queue Depth + Latency = Powerful Signal

Suppose:

```text
VolumeQueueLength:
rising

Latency:
rising

IOPS:
at provisioned limit
```

Very strong clue:

```text
volume performance ceiling
```

But:

```text
Queue:
low

Latency:
normal

IOPS:
low
```

then storage probably isn't the immediate bottleneck.

---

# 21. CloudWatch EBS Metrics

AWS automatically publishes EBS metrics to CloudWatch in one-minute periods. ([AWS Documentation][3])

Metrics you should know:

```text
VolumeReadOps
VolumeWriteOps

VolumeReadBytes
VolumeWriteBytes

VolumeQueueLength

VolumeAvgReadLatency
VolumeAvgWriteLatency

VolumeIOPSExceededCheck

VolumeThroughputExceededCheck

BurstBalance
```

Some newer detailed metrics require a Nitro-attached EBS volume. ([AWS Documentation][3])

---

# 22. Calculate IOPS from CloudWatch

Suppose:

```text
VolumeReadOps Sum over 60 seconds
=
120,000
```

Then:

```text
120,000 / 60

= 2,000 read IOPS
```

Suppose writes:

```text
VolumeWriteOps
=
60,000 per minute
```

Then:

```text
60,000 / 60
=
1,000 write IOPS
```

Total approximate workload:

```text
2,000 + 1,000
=
3,000 IOPS
```

AWS's documentation uses the same operations-divided-by-period calculation for deriving per-second IOPS. ([AWS Documentation][3])

---

# 23. Calculate Throughput

Suppose CloudWatch shows:

```text
VolumeReadBytes
=
6 GiB over 60 seconds
```

Approximately:

```text
6 GiB
=
6144 MiB
```

Therefore:

```text
6144 / 60
≈ 102.4 MiB/s
```

Add writes too if you need aggregate throughput.

AWS's EC2/EBS metrics similarly derive bytes per second by dividing transferred bytes by the measurement period. ([AWS Documentation][3])

---

# 24. A Much Easier Modern Metric

For Nitro-attached EBS volumes, AWS now provides:

```text
VolumeIOPSExceededCheck
```

It reports:

```text
0 = volume provisioned IOPS wasn't exceeded

1 = application consistently attempted
    to exceed provisioned IOPS
```

Likewise:

```text
VolumeThroughputExceededCheck
```

indicates whether the workload consistently attempted to exceed the volume's provisioned throughput. ([AWS Documentation][3])

This makes troubleshooting significantly easier.

---

# 25. Volume Limit vs Instance Limit

This distinction is critical.

Suppose:

```text
VolumeIOPSExceededCheck = 0
```

but:

```text
InstanceEBSIOPSExceededCheck = 1
```

What does that mean?

```text
The volume isn't the bottleneck.

The EC2 instance's EBS capability is.
```

AWS publishes `InstanceEBSIOPSExceededCheck` and `InstanceEBSThroughputExceededCheck` for supported Nitro instances specifically to detect when aggregate EBS traffic exceeds the EC2 instance's EBS limits. ([AWS Documentation][3])

This is production-grade diagnosis.

---

# 26. Example

Imagine:

```text
gp3 volume:

16,000 IOPS
500 MiB/s
```

But your instance can only sustain:

```text
8,000 IOPS
250 MiB/s
```

Increasing:

```text
16,000 → 30,000 volume IOPS
```

does nothing useful.

Because:

```text
EC2
 │
 ├────── 8k ceiling
 │
 ▼
EBS provisioned 30k
```

The correct fix may be:

```text
larger/different EC2 instance
```

not:

```text
more EBS IOPS
```

---

# 27. EBS-Optimized EC2

AWS EBS-optimized instances provide an optimized path with dedicated EBS I/O bandwidth intended to reduce contention with other instance network traffic. Most modern relevant EC2 families provide EBS optimization by default, but the exact bandwidth and burst behavior depends on the instance type. ([AWS Documentation][5])

Never select EC2 using only:

```text
vCPU
RAM
```

For storage-heavy workloads inspect:

```text
vCPU
RAM
Network bandwidth
EBS bandwidth
EBS IOPS capability
local instance storage
```

---

# 28. EBSIOBalance% and EBSByteBalance%

Some burst-capable EC2 instance sizes have instance-level EBS burst credits.

Useful metrics:

```text
EBSIOBalance%
EBSByteBalance%
```

AWS describes them as I/O and throughput credit balances respectively; consistently low values can indicate that the EC2 instance itself should be sized up. ([AWS Documentation][6])

Think:

```text
Volume has capacity
      │
      ▼
Instance EBS credits exhausted
      │
      ▼
application slows
```

Again:

```text
disk upgrade
```

might be the wrong solution.

---

# 29. Linux Troubleshooting Tools

CloudWatch tells us what AWS sees.

Inside Linux we need OS-level visibility.

Useful tools:

```text
lsblk
df
iostat
pidstat
vmstat
iotop
fio
```

Let's focus on the most useful ones.

---

# 30. `lsblk`

Start with:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
```

Example:

```text
NAME         SIZE TYPE FSTYPE MOUNTPOINTS
nvme0n1       30G disk
└─nvme0n1p1   30G part xfs    /

nvme1n1      100G disk xfs    /data
```

On Nitro instances, EBS volumes appear as NVMe devices such as `/dev/nvme0n1`, `/dev/nvme1n1`, and enumeration order isn't guaranteed to match your original block-device mapping order. ([AWS Documentation][7])

So never blindly assume:

```text
nvme1n1 = database
```

Verify.

---

# 31. `df`

```bash
df -hT
```

Shows:

```text
filesystem size
used
available
filesystem type
mount point
```

Example:

```text
Filesystem      Type  Size Used Avail Use%
/dev/nvme1n1    xfs   100G  92G   8G  92%
```

Important distinction:

```text
lsblk
=
block-device view

df
=
mounted-filesystem view
```

---

# 32. `iostat`

Install sysstat if needed:

Amazon Linux:

```bash
sudo dnf install -y sysstat
```

Ubuntu:

```bash
sudo apt update
sudo apt install -y sysstat
```

Then:

```bash
iostat -xz 1
```

Important columns vary somewhat by sysstat version, but commonly include:

```text
r/s
w/s

rkB/s
wkB/s

await

aqu-sz

%util
```

Mental mapping:

```text
r/s + w/s
≈ OS-visible IOPS

rkB/s + wkB/s
≈ throughput

await
≈ latency

aqu-sz
≈ queue depth
```

---

# 33. How to Read `iostat`

Example:

```text
Device       r/s     w/s     await    aqu-sz
nvme1n1     1500    1400       2.0      2.4
```

Looks reasonably healthy depending on workload expectations.

But:

```text
Device       r/s     w/s     await    aqu-sz
nvme1n1     1500    1500      40.0     55.0
```

Now we have:

```text
queue huge
+
latency high
```

Strong signal that storage requests are backing up.

Don't diagnose using `%util` alone on modern virtual/NVMe storage.

Correlate:

```text
IOPS
throughput
latency
queue
CloudWatch
```

---

# 34. `iotop`

To discover **which process is doing the I/O**:

```bash
sudo iotop
```

or:

```bash
sudo iotop -oPa
```

You might discover:

```text
postgres
mysql
java
node
backup-agent
log-compressor
```

is generating the pressure.

This prevents:

```text
upgrade infrastructure
```

when the actual issue is:

```text
runaway backup script
```

---

# 35. `fio`

`fio` is extremely useful for controlled storage benchmarking.

But:

> **Do not run destructive fio tests against production data devices.**

AWS itself provides EBS benchmarking guidance and discusses controlling block size, queue depth and workload type when testing volumes. ([AWS Documentation][8])

Use a dedicated test volume.

Install:

```bash
sudo dnf install -y fio
```

or:

```bash
sudo apt install -y fio
```

---

# 36. Random Read IOPS Test

Example:

```bash
fio \
  --name=random-read \
  --filename=/data/fio-test \
  --size=4G \
  --rw=randread \
  --bs=16k \
  --iodepth=32 \
  --numjobs=1 \
  --direct=1 \
  --runtime=60 \
  --time_based \
  --group_reporting
```

Important parameters:

```text
rw=randread
=
random reads

bs=16k
=
16 KiB I/O size

iodepth=32
=
up to 32 outstanding requests

direct=1
=
reduce page-cache interference

runtime=60
=
run 60 seconds
```

---

# 37. Throughput-Oriented Test

For larger sequential transfers:

```bash
fio \
  --name=seq-read \
  --filename=/data/fio-test \
  --size=8G \
  --rw=read \
  --bs=1M \
  --iodepth=16 \
  --direct=1 \
  --runtime=60 \
  --time_based \
  --group_reporting
```

Now you're testing something closer to:

```text
large sequential throughput
```

rather than small random IOPS.

---

# 38. Never Compare fio Tests Without Matching Workload

These two results are not equivalent:

```text
Test A
4 KiB random

Test B
1 MiB sequential
```

Why?

Because:

```text
I/O size
+
access pattern
+
queue depth
+
read/write ratio
```

all influence the result.

AWS also explains that SSD EBS can merge sequential small I/O or split oversized I/O operations, which affects how operations are counted. ([AWS Documentation][1])

---

# 39. Online EBS Resize

Now let's solve another production incident.

Current:

```text
/data

100 GiB
95% full
```

We need:

```text
200 GiB
```

Elastic Volumes can increase the EBS volume without detaching it or rebooting supported instances. ([AWS Documentation][9])

AWS CLI:

```bash
aws ec2 modify-volume \
  --volume-id vol-0123456789abcdef0 \
  --size 200 \
  --region ap-south-1
```

Check:

```bash
aws ec2 describe-volumes-modifications \
  --volume-ids vol-0123456789abcdef0 \
  --region ap-south-1
```

---

# 40. But `df -h` Still Says 100G!

Because remember:

```text
AWS layer
≠
Linux filesystem layer
```

After modifying EBS:

```text
EBS volume    = 200 GiB

partition     = maybe 100 GiB

filesystem   = maybe 100 GiB
```

AWS explicitly documents that after volume expansion you may also need to grow the partition and filesystem. ([AWS Documentation][10])

---

# 41. First Inspect

```bash
lsblk
```

Suppose:

```text
nvme0n1       200G
└─nvme0n1p1   100G /
```

This tells you:

```text
AWS/block device grew
but partition did not.
```

---

# 42. Extend Partition

For:

```text
/dev/nvme0n1p1
```

run:

```bash
sudo growpart /dev/nvme0n1 1
```

Notice:

```text
device:
nvme0n1

partition number:
1
```

with a space between them.

AWS documents this exact Nitro example for expanding an EBS partition. ([AWS Documentation][10])

Verify:

```bash
lsblk
```

Now:

```text
nvme0n1       200G
└─nvme0n1p1   200G /
```

---

# 43. Filesystem Still Needs Expansion

Now:

```bash
df -hT
```

may still say:

```text
100G
```

because:

```text
partition = 200G
filesystem = 100G
```

We now expand the filesystem.

---

# 44. XFS

Check:

```bash
df -hT
```

If:

```text
Type = xfs
```

and mounted at `/`:

```bash
sudo xfs_growfs -d /
```

For `/data`:

```bash
sudo xfs_growfs /data
```

AWS instructs using `xfs_growfs` against the mount point for an XFS filesystem. ([AWS Documentation][10])

---

# 45. ext4

If:

```text
Type = ext4
```

run against the filesystem device:

```bash
sudo resize2fs /dev/nvme0n1p1
```

AWS documents `resize2fs` for ext4 EBS filesystem expansion. ([AWS Documentation][10])

Verify:

```bash
df -hT
```

Expected:

```text
200G
```

---

# 46. The Resize Chain

Memorize:

```text
AWS ModifyVolume
      │
      ▼
lsblk
      │
      ▼
Partition needs growth?
      │
   YES│
      ▼
growpart
      │
      ▼
Filesystem?
 ┌────┴────┐
 │         │
XFS       ext4
 │         │
 ▼         ▼
xfs_     resize2fs
growfs
 │
 └────┬────┘
      ▼
df -hT
```

---

# 47. Troubleshooting Example 1

Problem:

```text
Database latency high
```

CloudWatch:

```text
VolumeIOPSExceededCheck = 1

VolumeThroughputExceededCheck = 0
```

Interpretation:

```text
IOPS bottleneck
```

Potential actions:

```text
increase gp3 IOPS
optimize DB I/O
batch operations
increase caching
consider io2 if workload requires it
```

Not:

```text
increase gp3 throughput
```

because throughput isn't currently the exceeded resource. ([AWS Documentation][3])

---

# 48. Troubleshooting Example 2

CloudWatch:

```text
VolumeIOPSExceededCheck = 0

VolumeThroughputExceededCheck = 1
```

Interpretation:

```text
large-I/O / throughput bottleneck
```

Potential solution:

```text
increase gp3 throughput
```

provided:

```text
instance EBS bandwidth
```

can support it. ([AWS Documentation][3])

---

# 49. Troubleshooting Example 3

CloudWatch:

```text
VolumeIOPSExceededCheck = 0

VolumeThroughputExceededCheck = 0

InstanceEBSThroughputExceededCheck = 1
```

Interpretation:

```text
EBS volume is okay.

EC2 EBS bandwidth is saturated.
```

Solution direction:

```text
different/larger EC2 instance
```

not more volume throughput. ([AWS Documentation][3])

---

# 50. Troubleshooting Example 4

You resized:

```text
100 GiB → 200 GiB
```

AWS console:

```text
200 GiB
```

Linux:

```text
df -h

100 GiB
```

Diagnosis:

```text
cloud block device changed

but

partition/filesystem did not
```

Check:

```bash
lsblk
df -hT
```

Then use:

```text
growpart
+
xfs_growfs
```

or:

```text
growpart
+
resize2fs
```

as appropriate. ([AWS Documentation][10])

---

# 51. Troubleshooting Example 5

Application suddenly slows every day at midnight.

CPU:

```text
normal
```

EBS queue:

```text
huge
```

Write throughput:

```text
spikes
```

Check running processes:

```bash
sudo iotop
```

Discover:

```text
midnight backup
```

The actual fix might be:

```text
reschedule backup
throttle backup I/O
snapshot differently
provision more temporary performance
change backup architecture
```

not:

```text
buy a bigger EC2 forever
```

---

# 52. Production Diagnosis Flow

For storage-related slowness:

```text
Application slow
      │
      ▼
Check CPU / RAM / network
      │
      ▼
Check storage
      │
      ├── Read/write IOPS
      │
      ├── Read/write throughput
      │
      ├── Latency
      │
      └── Queue depth
      │
      ▼
Volume exceeded?
      │
   ┌──┴──┐
   │     │
 YES     NO
   │     │
   ▼     ▼
Tune    Instance
EBS     exceeded?
          │
       ┌──┴──┐
       │     │
      YES    NO
       │     │
       ▼     ▼
   resize   OS/app
    EC2    investigation
```

---

# 53. The Three Bottleneck Levels

Memorize this.

```text
Level 1
APPLICATION
    │
    └── poor query / excess I/O / bad caching


Level 2
EBS VOLUME
    │
    ├── IOPS limit
    ├── throughput limit
    └── gp2 credits


Level 3
EC2 INSTANCE
    │
    ├── instance EBS IOPS limit
    └── instance EBS throughput limit
```

Sometimes buying more storage performance fixes nothing because the bottleneck is level 1 or level 3.

---

# 54. Terraform gp3 Example

```hcl
resource "aws_ebs_volume" "data" {
  availability_zone = "ap-south-1a"

  type = "gp3"

  size = 200

  iops = 6000

  throughput = 250

  encrypted = true

  tags = {
    Name        = "prod-data"
    Environment = "production"
  }
}
```

Attachment:

```hcl
resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"

  volume_id = aws_ebs_volume.data.id

  instance_id = aws_instance.app.id
}
```

On Nitro, remember the Linux operating system may expose `/dev/sdf` as an NVMe name such as `/dev/nvme1n1`. ([AWS Documentation][7])

---

# 55. Launch Template Root Volume

Production ASG example:

```hcl
resource "aws_launch_template" "app" {

  # ...

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type = "gp3"

      volume_size = 30

      iops = 3000

      throughput = 125

      encrypted = true

      delete_on_termination = true
    }
  }
}
```

Now your fleet gets a predictable root-storage configuration every time.

---

# 56. Certification Scenario

### Question

An application performs:

```text
many small random database reads
```

and storage is saturated.

What matters most?

Think:

```text
IOPS
+
latency
```

---

### Question

A data-processing system reads:

```text
huge sequential files
```

What matters most?

Think:

```text
throughput
```

---

### Question

gp3 is provisioned at:

```text
16,000 IOPS
```

but workload only achieves 8,000.

What should you inspect?

Don't immediately increase gp3.

Check:

```text
InstanceEBSIOPSExceededCheck
EC2 instance EBS limits
queue depth
I/O generation rate
```

AWS specifically recommends verifying that the EC2 instance itself isn't limiting EBS performance. ([AWS Documentation][1])

---

# 57. Interview Scenario

Interviewer:

> “Our database became slow. CPU is only 25%. What would you investigate?”

Strong answer:

> I'd first correlate database latency with EBS read/write IOPS, throughput, queue depth and latency. I'd check `VolumeIOPSExceededCheck` and `VolumeThroughputExceededCheck` to determine whether the EBS volume itself is saturated, then check `InstanceEBSIOPSExceededCheck` and `InstanceEBSThroughputExceededCheck` to see whether the EC2 instance's EBS bandwidth is the bottleneck. Inside Linux I'd use `iostat` and process-level I/O tools to identify the workload generating the I/O. I'd only increase IOPS, throughput or EC2 size after identifying the actual limiting layer.

That's a much stronger answer than:

> “Upgrade the instance.”

---

# 58. Never-Forget Formula

```text
THROUGHPUT
≈
IOPS × I/O SIZE
```

But:

```text
Actual Throughput
=
MIN(
  workload demand,
  volume throughput,
  volume IOPS × I/O size,
  EC2 EBS bandwidth
)
```

That's the real mental model.

---

# 59. Never-Forget gp2 vs gp3

```text
gp2

SIZE
 ↓
PERFORMANCE

+
BURST CREDITS
```

versus:

```text
gp3

SIZE
IOPS
THROUGHPUT

configured much more independently

+
NO gp2-style burst credits
```

AWS currently documents gp3 at 3,000 baseline IOPS / 125 MiB/s and no burst mechanism, versus gp2's size-dependent IOPS and credit-based bursting below the applicable thresholds. ([AWS Documentation][2])

---

# 60. Never-Forget Troubleshooting Chain

```text
Application slow
      ↓
CPU?
      ↓
Memory?
      ↓
Network?
      ↓
Storage?
      ↓
IOPS?
      ↓
Throughput?
      ↓
Latency?
      ↓
Queue?
      ↓
Volume limit?
      ↓
Instance EBS limit?
      ↓
Filesystem?
      ↓
Application I/O pattern?
```

Don't skip layers.

---

# Lesson 25 Progress

We have now covered:

```text
✓ EBS fundamentals
✓ Block storage
✓ EBS vs S3
✓ EBS vs Instance Store
✓ Root vs data volumes
✓ DeleteOnTermination
✓ Volume types
✓ gp3
✓ gp2
✓ gp2 burst credits
✓ gp2 → gp3 migration
✓ io2 Block Express
✓ IOPS
✓ throughput
✓ latency
✓ queue depth
✓ I/O size
✓ EC2 EBS bandwidth
✓ EBS-optimized instances
✓ CloudWatch EBS metrics
✓ volume-vs-instance bottlenecks
✓ Linux troubleshooting
✓ fio concepts
✓ Elastic Volumes
✓ growpart
✓ xfs_growfs
✓ resize2fs
✓ production troubleshooting
```

## Next — Lesson 25 Part 3

Next we move from **performance** into **data protection and disaster recovery**:

```text
EBS SNAPSHOTS & BACKUP ENGINEERING
           │
           ├── snapshot internals
           ├── incremental snapshots
           ├── snapshot dependency myth
           ├── crash consistency
           ├── application consistency
           ├── database snapshot strategy
           ├── multi-volume snapshots
           ├── snapshot restore behavior
           ├── lazy loading
           ├── initialization
           ├── Fast Snapshot Restore
           ├── EBS volume copy
           ├── cross-AZ recovery
           ├── cross-Region snapshot copy
           ├── cross-account backup
           ├── encryption + KMS
           ├── AWS Data Lifecycle Manager
           ├── AWS Backup
           ├── RPO / RTO design
           ├── accidental-deletion recovery
           ├── Terraform backup design
           └── hands-on disaster-recovery lab
```

That is where EBS stops being only **“a disk attached to EC2”** and becomes part of a real **backup, recovery and disaster-resilience architecture**.

[1]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-io-characteristics.html "Amazon EBS I/O characteristics and monitoring - Amazon EBS"
[2]: https://docs.aws.amazon.com/ebs/latest/userguide/general-purpose.html "Amazon EBS General Purpose SSD volumes - Amazon EBS"
[3]: https://docs.aws.amazon.com/ebs/latest/userguide/using_cloudwatch_ebs.html "Amazon CloudWatch metrics for Amazon EBS - Amazon EBS"
[4]: https://docs.aws.amazon.com/ebs/latest/userguide/provisioned-iops.html "Amazon EBS Provisioned IOPS SSD volumes - Amazon EBS"
[5]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-optimized.html?utm_source=chatgpt.com "Amazon EBS-optimized instance types"
[6]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-optimization-performance.html "Get the maximum Amazon EBS optimized performance - Amazon Elastic Compute Cloud"
[7]: https://docs.aws.amazon.com/ebs/latest/userguide/nvme-ebs-volumes.html?utm_source=chatgpt.com "Amazon EBS volumes and NVMe"
[8]: https://docs.aws.amazon.com/ebs/latest/userguide/benchmark_procedures.html?utm_source=chatgpt.com "Benchmark Amazon EBS volumes"
[9]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-modify-volume.html?utm_source=chatgpt.com "Modify an Amazon EBS volume using Elastic ..."
[10]: https://docs.aws.amazon.com/ebs/latest/userguide/recognize-expanded-volume-linux.html "Extend the file system after resizing an Amazon EBS volume - Amazon EBS"
