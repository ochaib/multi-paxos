# distributed algorithms, n.dulay, 29 jan 21
# coursework, paxos made moderately complex

# make options for Multipaxos

CLEAN UP
--------
make clean   - remove compiled code
make compile - compile 

make run cluster     - same as make run SERVERS=5 CLIENTS=5 CONFIG=default DEBUG=0 MAX_TIME=15000

make run_faster      - same as make run SERVERS=5 CLIENTS=5 CONFIG=faster DEBUG=0 MAX_TIME=15000
