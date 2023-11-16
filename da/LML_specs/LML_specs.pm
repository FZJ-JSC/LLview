# Copyright (c) 2023 Forschungszentrum Juelich GmbH.
# This file is part of LLview. 
#
# This is an open source software distributed under the GPLv3 license. More information see the LICENSE file at the top level.
#
# Contributions must follow the Contributor License Agreement. More information see the CONTRIBUTING.md file at the top level.
#
# Contributors:
#    Wolfgang Frings (Forschungszentrum Juelich GmbH) 

package LML_specs;

use strict;

# [type, req, info, description ]
# type:
#    k    -> keywords
#    s    -> string
#    d    -> integer
#    D    -> Date
#    f    -> float
# req:
#    M    -> Mandatory (also in job list table)
#    m    -> Mandatory
#    O    -> Optional
# description: 
#    -> string

$LML_specs::LMLattributes = {
    "job" => {
            "owner"          => ["s","M", undef, "uid of owner of job"],
            "group"          => ["s","M", undef, "gid of owner of job"],
            "status"         => ["k","M",{
                                          "UNDETERMINED" => 1,
                                          "SUBMITTED"    => 1,
                                          "RUNNING"      => 1,
                                          "SUSPENDED"    => 1,
                                          "COMPLETED"    => 1,
                                          }, "Primary status of job" 
                                ],
            "detailedstatus" => ["k","M",{
                                          "QUEUED_ACTIVE"        => 1, 
                                          "SYSTEM_ON_HOLD"       => 1, # Submitted
                                          "USER_ON_HOLD"         => 1, # Submitted
                                          "USER_SYSTEM_ON_HOLD"  => 1, # Submitted
                                          "SYSTEM_SUSPENDED"     => 1, # Suspended
                                          "USER_SUSPENDED"       => 1, # Suspended
                                          "USER_SYSTEM_SUSPENDED"=> 1, # Suspended
                                          "FAILED"               => 1, # Completed
                                          "CANCELED"             => 1, # Completed
                                          "JOB_OUTERR_READY"     => 1, # Completed
                                          }, "Detailed status of job" 
                                  ],
            "state"          => ["k","O",{
                                          "Running"    => 1,
                                          "Completed"  => 1,
                                          "Idle"       => 1,
                                          "Not Queued" => 1,
                                          "Removed"    => 1,
                                          "User Hold"  => 1,
                                          "System Hold"=> 1,
                                          }, "Status of Job" 
                                ],
            "wall"         => ["d","m",undef, "requested wall time for this job (s)" ],
            "wallsoft"     => ["d","O",undef, "requested wall time for this job (s), soft limit" ],
            "queuedate"    => ["D","m",undef, "date job was inserted in queue (submit)"], 
            "eligdate"     => ["D","O",undef, "date the job is eligible for running"],
            "name"         => ["s","O",undef, "used defined name of job" ],
            "step"         => ["s","M",undef, "unique job id" ],
            "comment"      => ["s","O",undef, "comment" ],
            "totalcores"   => ["d","M",undef, "total number of machine cores requested"],
            "totaltasks"   => ["d","M",undef, "total number of (MPI) tasks"],
            "totalgpus"    => ["d","O",undef, "total number of GPUs requested"],
            "nodelist"     => ["s","M",undef, "node on which a job is running" ],
            "gpulist"      => ["s","O",undef, "gpu nodes on which a job is running" ],
            "vnodelist"    => ["s","O",undef, "virtual node list (PBS), used first" ],
            "prenodelist"  => ["s","O",undef, "prediction by RMS for node list" ],
            "queue"        => ["s","M",undef, "queue"],
            "dependency"   => ["s","O",undef, "dependency string"],
            "qos"          => ["s","O",undef, "quality of service"],
            "executable"   => ["s","O",undef, "path and name of executable"],
            "spec"         => ["s","O",undef, "size specification (like n<n>p<p>t<t>)"],
# LL optional
            "classprio"    => ["d","O",undef, ""], 
            "groupprio"    => ["d","O",undef, ""], 
            "userprio"     => ["d","O",undef, ""], 
            "favored"      => ["s","O",undef, ""], 
            "restart"      => ["s","O",undef, ""], 
# BG optional
            "sysprio"           => ["s","O",undef, ""],
            "bg_partalloc"      => ["s","O",undef, ""],
            "bg_partreq"        => ["s","O",undef, ""],
            "nodelist_boards"   => ["s","O",undef, ""],
            "bg_size_alloc"     => ["s","O",undef, ""],
            "bg_size_req"       => ["s","O",undef, ""],
            "bg_shape_alloc"    => ["s","O",undef, ""],
            "bg_shape_req"      => ["s","O",undef, ""],
            "bg_state"          => ["s","O",undef, ""],
            "bg_type"           => ["s","O",undef, ""],
# BG/P optional
            "bgp_partalloc"      => ["s","O",undef, ""],
            "bgp_size_alloc"     => ["s","O",undef, ""],
            "bgp_size_req"       => ["s","O",undef, ""],
            "bgp_shape_alloc"    => ["s","O",undef, ""],
            "bgp_shape_req"      => ["s","O",undef, ""],
            "bgp_state"          => ["s","O",undef, ""],
            "bgp_type"           => ["s","O",undef, ""],
# I/O
            "fs_br_work"         => ["f","O",undef, ""],
            "fs_bw_work"         => ["f","O",undef, ""],
            "fs_bwr_work"        => ["f","O",undef, ""],
            "fs_bww_work"        => ["f","O",undef, ""],
            "fs_ooc_work"        => ["f","O",undef, ""],
            "fs_oocr_work"       => ["f","O",undef, ""],
            "fs_br_home"         => ["f","O",undef, ""],
            "fs_bw_home"         => ["f","O",undef, ""],
            "fs_bwr_home"        => ["f","O",undef, ""],
            "fs_bww_home"        => ["f","O",undef, ""],
            "fs_ooc_home"        => ["f","O",undef, ""],
# I/O
            "memU_avg"           => ["f","O",undef, ""],
            "memU_max"           => ["f","O",undef, ""],
            "load_avg"           => ["f","O",undef, ""],
            "load_max"           => ["f","O",undef, ""],
# SLURM optional
            "account"            => ["s","O",undef, "SLURM usage account"],
            "command"            => ["s","O",undef, "SLURM running batch command"],
            "runtime"            => ["d","O",undef, "SLURM current job runtime"],
            "starttime"          => ["s","O",undef, "SLURM start date of job (pred)"],
            "endtime"            => ["s","O",undef, "SLURM end date of job (pred)"],
            "numnodes"           => ["d","O",undef, "SLURM number of nodes"],
            "reason"             => ["s","O",undef, "SLURM reason for not scheduling"],
            "ArrayJobId"         => ["s","O",undef, "SLURM Array-Job Id"], 
            "ArrayTaskId"        => ["s","O",undef, "SLURM Array-Job Task-Id"], 
            "jobname"            => ["s","O",undef, "SLURM jobname"], 
# MOAB optional
            "systemprio"          => ["s","O",undef, "SLURM usage account"],
            "topdog"              => ["s","O",undef, "SLURM running batch command"],
            "eligible"            => ["d","O",undef, "SLURM current job runtime"],
# TORQUE optional
            "ppn"                => ["d","O",undef, "Processes per node"],
            "tpt"                => ["d","O",undef, "Threads per task"]
            },
    "node" => {
            "id"             => ["s","M", undef, ""],
            "ncores"         => ["i","M", undef, ""],
            "physmem"        => ["i","M", undef, ""],
            "availmem"       => ["i","M", undef, ""],
            "detailedstate"  => ["s","O", undef, ""],
            "state"          => ["k","M",{
                                          "Running"    => 1,
                                          "Idle"       => 1,
                                          "Drained"    => 1,
                                          "Down"       => 1,
                                          "Unknown"    => 1,
                                          "Maint"      => 1,
                                          }, ""
                                ],
            }
};

1;
