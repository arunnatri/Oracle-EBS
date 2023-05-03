--
-- XXD_DEBUG_TOOLS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_DEBUG_TOOLS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_DEBUG_TOOLS_PKG
    * Design       : This package will handle debug log messages
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 05-Mar-2020  1.0        Deckers                 Initial Version
    -- 27-Jul-2021  1.1        Deckers                 Updated for CCR0009490
    -- 16-Aug-2021  1.2        Deckers                 Updated for CCR0009529 to replace the DB link name
    -- 10-Mar-2022  1.3        Viswanathan Pandian     Updated for CCR0009841 to fix sessions table multi row
    ******************************************************************************************/

    gb_is_remote       BOOLEAN := FALSE;
    gb_is_registered   BOOLEAN := FALSE;
    gc_db_link_name    VARCHAR2 (64);
    gc_instance_type   VARCHAR2 (4);
    gb_is_production   BOOLEAN := TRUE;
    gn_log_filter      NUMBER := 1;
    gb_is_slave        BOOLEAN := TRUE;
    gn_msg_count       NUMBER := 0;
    gr_empty_msg       xxdo.xxd_debug_t%ROWTYPE;
    gr_default_msg     xxdo.xxd_debug_t%ROWTYPE;
    gr_session_info    gv$session%ROWTYPE;
    gr_instance_info   v$instance%ROWTYPE;
    gt_first_message   TIMESTAMP;
    gt_last_message    TIMESTAMP;
    gn_start_ms        NUMBER;
    gn_last_ms         NUMBER;
    gc_dblink_info     VARCHAR2 (200);
    gn_msg_limit       NUMBER := 1;

    gc_origin          VARCHAR2 (64);

    TYPE call_stack_rec_typ IS RECORD
    (
        call_order       NUMBER,
        object_handle    VARCHAR2 (2000),
        line_num         NUMBER,
        object_name      VARCHAR2 (2000)
    );

    TYPE call_stack_tbl_typ IS TABLE OF call_stack_rec_typ
        INDEX BY BINARY_INTEGER;

    TYPE metrics IS TABLE OF NUMBER
        INDEX BY VARCHAR2 (64);

    g_depths           metrics;

    PROCEDURE set_attributes (pn_attribute_num     IN NUMBER,
                              pc_attribute_value   IN VARCHAR2)
    AS
    BEGIN
        IF pn_attribute_num = 1
        THEN
            gr_default_msg.attribute_01   := pc_attribute_value;
        ELSIF pn_attribute_num = 2
        THEN
            gr_default_msg.attribute_02   := pc_attribute_value;
        ELSIF pn_attribute_num = 3
        THEN
            gr_default_msg.attribute_03   := pc_attribute_value;
        ELSIF pn_attribute_num = 4
        THEN
            gr_default_msg.attribute_04   := pc_attribute_value;
        ELSIF pn_attribute_num = 5
        THEN
            gr_default_msg.attribute_05   := pc_attribute_value;
        ELSIF pn_attribute_num = 6
        THEN
            gr_default_msg.attribute_06   := pc_attribute_value;
        ELSIF pn_attribute_num = 7
        THEN
            gr_default_msg.attribute_07   := pc_attribute_value;
        ELSIF pn_attribute_num = 8
        THEN
            gr_default_msg.attribute_08   := pc_attribute_value;
        ELSIF pn_attribute_num = 9
        THEN
            gr_default_msg.attribute_09   := pc_attribute_value;
        ELSIF pn_attribute_num = 10
        THEN
            gr_default_msg.attribute_10   := pc_attribute_value;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('others exception in set_attributes ' || SQLERRM);
    END set_attributes;

    PROCEDURE clear_attributes
    AS
    BEGIN
        gr_default_msg.attribute_01   := NULL;
        gr_default_msg.attribute_02   := NULL;
        gr_default_msg.attribute_03   := NULL;
        gr_default_msg.attribute_04   := NULL;
        gr_default_msg.attribute_05   := NULL;
        gr_default_msg.attribute_06   := NULL;
        gr_default_msg.attribute_07   := NULL;
        gr_default_msg.attribute_08   := NULL;
        gr_default_msg.attribute_09   := NULL;
        gr_default_msg.attribute_10   := NULL;
    END clear_attributes;

    FUNCTION parse_call_stack (pc_stack VARCHAR2)
        RETURN call_stack_tbl_typ
    IS
        ln_string_index      NUMBER;
        ln_string_nl_index   NUMBER;
        lc_call_string       VARCHAR2 (2000);
        lc_object_handle     VARCHAR2 (2000);
        lc_line_number       VARCHAR2 (2000);
        lc_object_name       VARCHAR2 (2000);
        ln_stack_depth       NUMBER;
        l_stack              call_stack_tbl_typ;
        c_nl        CONSTANT CHAR (1) := CHR (10);
    BEGIN
        ln_string_index   := INSTR (pc_stack, 'name') + 5;
        ln_stack_depth    := 1;

        WHILE ln_string_index < LENGTH (pc_stack)
        LOOP
            ln_string_nl_index                       := INSTR (pc_stack, c_nl, ln_string_index);
            lc_call_string                           :=
                SUBSTR (pc_stack,
                        ln_string_index,
                        ln_string_nl_index - ln_string_index);
            ln_string_index                          :=
                ln_string_index + LENGTH (lc_call_string) + 1;
            lc_call_string                           := LTRIM (lc_call_string);
            l_stack (ln_stack_depth).object_handle   :=
                SUBSTR (lc_call_string, 1, INSTR (lc_call_string, ' '));
            lc_call_string                           :=
                LTRIM (
                    SUBSTR (
                        lc_call_string,
                        LENGTH (l_stack (ln_stack_depth).object_handle) + 1));
            l_stack (ln_stack_depth).line_num        :=
                TO_NUMBER (
                    SUBSTR (lc_call_string, 1, INSTR (lc_call_string, ' ')));
            l_stack (ln_stack_depth).object_name     :=
                LTRIM (
                    SUBSTR (lc_call_string,
                            LENGTH (l_stack (ln_stack_depth).line_num) + 1));
            l_stack (ln_stack_depth).call_order      := ln_stack_depth;
            ln_stack_depth                           := ln_stack_depth + 1;
        END LOOP;

        RETURN l_stack;
    END parse_call_stack;

    PROCEDURE update_log_level
    AS
    BEGIN
        IF    INSTR (UPPER (gr_instance_info.instance_name), 'SNP') != 0
           OR INSTR (UPPER (gr_instance_info.instance_name), 'DEV') != 0
        THEN
            gb_is_production   := FALSE;
            gn_log_filter      :=
                NVL (fnd_profile.VALUE ('XXD_DEBUG_LEVEL'), 10000);
            gn_msg_limit       :=
                NVL (fnd_profile.VALUE ('XXD_DEBUG_LIMIT'), 10000000);
            oe_debug_pub.g_debug_level   :=
                GREATEST (oe_debug_pub.g_debug_level, 1);
        ELSE
            gb_is_production   := TRUE;
            gn_log_filter      :=
                NVL (fnd_profile.VALUE ('XXD_DEBUG_LEVEL'), 10);
            gn_msg_limit       :=
                NVL (fnd_profile.VALUE ('XXD_DEBUG_LIMIT'), 1000000);
        END IF;
    END update_log_level;

    PROCEDURE msg (pc_msg         VARCHAR2,
                   pn_log_level   NUMBER:= 9.99e125,
                   pc_origin      VARCHAR2:= 'Local Debug')
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        lr_msg             xxdo.xxd_debug_t%ROWTYPE := gr_default_msg;
        lt_msg_timestamp   TIMESTAMP := SYSTIMESTAMP;
        ln_msg_ms          NUMBER := DBMS_UTILITY.get_time;
        l_stack            call_stack_tbl_typ;
        ln_log_level       NUMBER (10, 0);
        lc_origin          VARCHAR (64);
        ln_calling_index   NUMBER (3, 0) := 1;
    BEGIN
        IF pn_log_level IS NULL OR pn_log_level = g_miss_num
        THEN
            NULL;
        ELSE
            lr_msg.log_level   := pn_log_level;
        END IF;

        IF lr_msg.log_level > gn_log_filter
        THEN
            RETURN;
        END IF;

        gn_msg_count             := gn_msg_count + 1;

        IF MOD (gn_msg_count, 1000) = 0
        THEN
            update_log_level;
        END IF;

        IF gn_msg_count > gn_msg_limit
        THEN
            RETURN;
        END IF;

        lr_msg.MESSAGE           := SUBSTR (pc_msg, 1, 2000);

        IF gn_msg_count = gn_msg_limit
        THEN
            lr_msg.MESSAGE   :=
                'Logging ends here since we reached the msg count limit ************';
        END IF;

        lr_msg.debug_id          := xxdo.xxd_debug_s.NEXTVAL;
        lr_msg.debug_date        := lt_msg_timestamp;
        lr_msg.debug_timestamp   := lt_msg_timestamp;
        lr_msg.message_ms        := ln_msg_ms;
        lr_msg.ms_elapsed        := ln_msg_ms - gn_last_ms;
        lr_msg.ms_elapsed        :=
              ((TO_NUMBER (TO_CHAR (lt_msg_timestamp, 'J')) - TO_NUMBER (TO_CHAR (gt_last_message, 'J'))) * 86400 + (EXTRACT (HOUR FROM lt_msg_timestamp) - EXTRACT (HOUR FROM gt_last_message)) * 3600 + (EXTRACT (MINUTE FROM lt_msg_timestamp) - EXTRACT (MINUTE FROM gt_last_message)) * 60 + EXTRACT (SECOND FROM lt_msg_timestamp) - EXTRACT (SECOND FROM gt_last_message))
            * 1000;
        lr_msg.mod_debug_date    := MOD (TO_CHAR (lt_msg_timestamp, 'J'), 30);
        lr_msg.call_stack        := DBMS_UTILITY.format_call_stack;
        l_stack                  := parse_call_stack (lr_msg.call_stack);

        BEGIN
            ln_calling_index   := g_depths (NVL (gc_origin, pc_origin));
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_calling_index   := -1;
        END;

        BEGIN
            IF ln_calling_index IS NOT NULL AND ln_calling_index >= 1
            THEN
                lr_msg.object_name   :=
                    SUBSTR (l_stack (ln_calling_index).object_name, 1, 128);
                lr_msg.object_line   := l_stack (ln_calling_index).line_num;
            ELSE
                lr_msg.object_name   := 'Unknown';
                lr_msg.object_line   := -1;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                lr_msg.object_name   := 'Unknown';
                lr_msg.object_line   := -2;
        END;

        lr_msg.origin            := NVL (gc_origin, pc_origin);

        INSERT INTO xxdo.xxd_debug_t
             VALUES lr_msg;

        gn_last_ms               := ln_msg_ms;
        gt_last_message          := lt_msg_timestamp;

        IF     gb_is_remote
           AND gc_db_link_name IS NOT NULL
           AND gc_db_link_name != g_miss_char
           AND NOT gb_is_slave
        THEN
            IF    NVL (gc_origin, pc_origin) = 'Local Debug'
               OR NVL (gc_origin, pc_origin) IS NULL
               OR NVL (gc_origin, pc_origin) = g_miss_char
            THEN
                lc_origin   := 'Remote Debug';
            ELSE
                lc_origin   :=
                    SUBSTR ('{Remote} ' || NVL (gc_origin, pc_origin), 1, 64);
            END IF;

            EXECUTE IMMEDIATE   'begin xxd_debug_tools_pkg.msg@'
                             || gc_db_link_name
                             || '(:1, :2, :3); exception when others then null; end;'
                USING IN pc_msg, IN pn_log_level, IN lc_origin;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
    END msg;

    PROCEDURE register_depth (pc_origin VARCHAR2, pn_depth NUMBER)
    IS
    BEGIN
        IF pc_origin IS NOT NULL AND pn_depth IS NOT NULL
        THEN
            g_depths (SUBSTR (pc_origin, 1, 64))   := ROUND (pn_depth, 0);
        END IF;
    END register_depth;

    PROCEDURE set_origin (pc_origin VARCHAR2 DEFAULT NULL)
    IS
    BEGIN
        IF pc_origin IS NOT NULL
        THEN
            gc_origin   := SUBSTR (pc_origin, 1, 64);
        ELSE
            gc_origin   := NULL;
        END IF;
    END set_origin;

    PROCEDURE register_controlling_session (pc_instance_name IN VARCHAR2, pc_host_name IN VARCHAR2, pc_username IN VARCHAR2, pc_machine IN VARCHAR2, pc_osuser IN VARCHAR2, pc_process IN VARCHAR2, pn_sid IN NUMBER, pn_serial# IN NUMBER, pn_audsid IN NUMBER, xc_instance_name OUT VARCHAR2, xc_host_name OUT VARCHAR2, xc_username OUT VARCHAR2, xc_machine OUT VARCHAR2, xc_osuser OUT VARCHAR2, xc_process OUT VARCHAR2
                                            , xn_sid OUT NUMBER, xn_serial# OUT NUMBER, xn_audsid OUT NUMBER)
    IS
    BEGIN
        IF gb_is_registered
        THEN
            RETURN;
        END IF;

        xc_instance_name                      := gr_default_msg.instance_name;
        xc_host_name                          := gr_default_msg.host_name;
        xc_username                           := gr_default_msg.username;
        xc_machine                            := gr_default_msg.machine;
        xc_osuser                             := gr_default_msg.osuser;
        xc_process                            := gr_default_msg.process;
        xn_sid                                := gr_default_msg.sid;
        xn_serial#                            := gr_default_msg.serial#;
        xn_audsid                             := gr_default_msg.audsid;
        gr_default_msg.remote_instance_name   := pc_instance_name;
        gr_default_msg.remote_host_name       := pc_host_name;
        gr_default_msg.remote_username        := pc_username;
        gr_default_msg.remote_machine         := pc_machine;
        gr_default_msg.remote_osuser          := pc_osuser;
        gr_default_msg.remote_process         := pc_process;
        gr_default_msg.remote_sid             := pn_sid;
        gr_default_msg.remote_serial#         := pn_serial#;
        gr_default_msg.remote_audsid          := pn_audsid;
        gb_is_slave                           := FALSE;

        IF     gb_is_remote
           AND gc_db_link_name IS NOT NULL
           AND gc_db_link_name != g_miss_char
        THEN
            EXECUTE IMMEDIATE   'begin xxd_debug_tools_pkg.register_hosting_session@'
                             || gc_db_link_name
                             || '(:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11, :12, :13, :14, :15, :16, :17, :18); exception when others then null; end;'
                USING IN gr_default_msg.remote_instance_name, IN gr_default_msg.remote_host_name, IN gr_default_msg.remote_username,
                      IN gr_default_msg.remote_machine, IN gr_default_msg.remote_osuser, IN gr_default_msg.remote_process,
                      IN gr_default_msg.remote_sid, IN gr_default_msg.remote_serial#, IN gr_default_msg.remote_audsid,
                      IN gr_default_msg.instance_name, IN gr_default_msg.host_name, IN gr_default_msg.username,
                      IN gr_default_msg.machine, IN gr_default_msg.osuser, IN gr_default_msg.process,
                      IN gr_default_msg.sid, IN gr_default_msg.serial#, IN gr_default_msg.audsid;
        END IF;
    END register_controlling_session;

    PROCEDURE register_hosting_session (p_instance_name IN VARCHAR2, p_host_name IN VARCHAR2, p_username IN VARCHAR2, p_machine IN VARCHAR2, p_osuser IN VARCHAR2, p_process IN VARCHAR2, p_sid IN NUMBER, p_serial# IN NUMBER, p_audsid IN NUMBER, p_remote_instance_name IN VARCHAR2, p_remote_host_name IN VARCHAR2, p_remote_username IN VARCHAR2, p_remote_machine IN VARCHAR2, p_remote_osuser IN VARCHAR2, p_remote_process IN VARCHAR2
                                        , p_remote_sid IN NUMBER, p_remote_serial# IN NUMBER, p_remote_audsid IN NUMBER)
    IS
    BEGIN
        gr_default_msg.instance_name          := p_instance_name;
        gr_default_msg.host_name              := p_host_name;
        gr_default_msg.username               := p_username;
        gr_default_msg.machine                := p_machine;
        gr_default_msg.osuser                 := p_osuser;
        gr_default_msg.process                := p_process;
        gr_default_msg.sid                    := p_sid;
        gr_default_msg.serial#                := p_serial#;
        gr_default_msg.audsid                 := p_audsid;
        gr_default_msg.remote_instance_name   := p_remote_instance_name;
        gr_default_msg.remote_host_name       := p_remote_host_name;
        gr_default_msg.remote_username        := p_remote_username;
        gr_default_msg.remote_machine         := p_remote_machine;
        gr_default_msg.remote_osuser          := p_remote_osuser;
        gr_default_msg.remote_process         := p_remote_process;
        gr_default_msg.remote_sid             := p_remote_sid;
        gr_default_msg.remote_serial#         := p_remote_serial#;
        gr_default_msg.remote_audsid          := p_remote_audsid;
        gb_is_slave                           := TRUE;
    END register_hosting_session;

    PROCEDURE init
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        gt_first_message                     := SYSTIMESTAMP;
        gn_start_ms                          := DBMS_UTILITY.get_time;
        gr_default_msg                       := gr_empty_msg;
        gt_last_message                      := gt_first_message;
        gn_last_ms                           := gn_start_ms;

        SELECT * INTO gr_instance_info FROM v$instance;

        SELECT *
          INTO gr_session_info
          FROM gv$session
         WHERE     audsid = SYS_CONTEXT ('USERENV', 'SESSIONID')
               AND inst_id = USERENV ('Instance')
               AND ROWNUM = 1;                   -- Added ronum for CCR0009841

        gc_dblink_info                       :=
            SUBSTR (SYS_CONTEXT ('USERENV', 'DBLINK_INFO'), 1, 200);

        IF gc_dblink_info IS NOT NULL
        THEN
            gb_is_remote   := TRUE;
        END IF;

        gr_default_msg.instance_name         := gr_instance_info.instance_name;
        gr_default_msg.host_name             := gr_instance_info.host_name;
        gr_default_msg.username              := gr_session_info.username;
        gr_default_msg.machine               := gr_session_info.machine;
        gr_default_msg.osuser                := gr_session_info.osuser;
        gr_default_msg.process               := gr_session_info.process;
        gr_default_msg.sid                   := gr_session_info.sid;
        gr_default_msg.serial#               := gr_session_info.serial#;
        gr_default_msg.audsid                := gr_session_info.audsid;
        update_log_level;

        IF    INSTR (UPPER (gr_instance_info.instance_name), 'SNP') != 0
           OR INSTR (UPPER (gr_instance_info.instance_name), 'DEV') != 0
        THEN
            gb_is_production   := FALSE;
            oe_debug_pub.g_debug_level   :=
                GREATEST (oe_debug_pub.g_debug_level, 1);
        ELSE
            gb_is_production   := TRUE;
        END IF;

        gr_default_msg.log_level             := 10000;

        IF INSTR (UPPER (gr_instance_info.instance_name), 'EBS') != 0
        THEN
            gc_instance_type   := 'EBS';
            gc_db_link_name    := 'BT_EBS_TO_ASCP.US.ORACLE.COM'; -- Added the full DB name for CCR0009529
        ELSIF INSTR (UPPER (gr_instance_info.instance_name), 'ASCP') != 0
        THEN
            gc_instance_type   := 'ASCP';
            gc_db_link_name    := 'BT_ASCP_TO_EBS.US.ORACLE.COM'; -- Added the full DB name for CCR0009529
        ELSE
            gc_instance_type   := 'UNKN';
        END IF;

        IF     NOT gb_is_remote
           AND gc_db_link_name IS NOT NULL
           AND gc_db_link_name != g_miss_char
           AND 1 = 2
        THEN      -- Added 1=2 to avoid recursive calls to ASCP for CCR0009490
            EXECUTE IMMEDIATE   'begin xxd_debug_tools_pkg.register_controlling_session@'
                             || gc_db_link_name
                             || '(:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11, :12, :13, :14, :15, :16, :17, :18); exception when others then null; end;'
                USING IN gr_default_msg.instance_name, IN gr_default_msg.host_name, IN gr_default_msg.username,
                      IN gr_default_msg.machine, IN gr_default_msg.osuser, IN gr_default_msg.process,
                      IN gr_default_msg.sid, IN gr_default_msg.serial#, IN gr_default_msg.audsid,
                      OUT gr_default_msg.remote_instance_name, OUT gr_default_msg.remote_host_name, OUT gr_default_msg.remote_username,
                      OUT gr_default_msg.remote_machine, OUT gr_default_msg.remote_osuser, OUT gr_default_msg.remote_process,
                      OUT gr_default_msg.remote_sid, OUT gr_default_msg.remote_serial#, OUT gr_default_msg.remote_audsid;
        END IF;

        g_depths ('Local Debug')             := 2;
        g_depths ('Remote Debug')            := 1;
        g_depths ('Local Delegated Debug')   := 3;
        COMMIT;
    END init;
BEGIN
    init;
END xxd_debug_tools_pkg;
/
