jsc_hpc_DBstat.yaml
----------------------------

This file has the definitions of tables used to store statistics
information of the database.


Data
~~~~

One table: ``LMLDBstat`` is defined in this ``yaml``
file.

..
  :doc:`jsc_hpc_DBstat.yaml<jsc_hpc_DBstat.yaml>`_
      
-----

Tables
~~~~~~

``LMLDBstat``

  +------+---------+---------+---------+-------+
  | ts   | db      | tab     | tabpath | nrows |
  +======+=========+=========+=========+=======+
  | ts_t | name_t  | name_t  | name_t  | cnt_t |
  +------+---------+---------+---------+-------+

  ``options`` keys:
  
      - ``update``: data on the table is updated using SQL by the ``sql_update_contents`` key correspoding to a SQL command stored in the dictionary ``sql``.
      - ``archive``: 
