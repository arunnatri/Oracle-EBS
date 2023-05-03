--
-- XXD_ONT_LDAP_UTILS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_LDAP_UTILS_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_LDAP_UTILS_PKG
    -- Design       : This package will be used to get ad groups
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 24-MAR-2021    Infosys              1.0    Initial Version

    -- #########################################################################################################################

    l_ldap_passwd   VARCHAR2 (256) := '33X@36ea';

    FUNCTION get_userdata (searchstring IN VARCHAR2)
        RETURN usr_tab_attr
        PIPELINED
    IS
        user_row        usr_attr_type;

        l_filter        VARCHAR2 (256) := searchString;

        l_retval        PLS_INTEGER;
        l_session       DBMS_LDAP.session;
        l_attrs         DBMS_LDAP.string_collection;

        v_entry_id      NUMBER (12);
        l_message       DBMS_LDAP.MESSAGE;
        l_entry         DBMS_LDAP.MESSAGE;
        l_attr_name     VARCHAR2 (256);
        l_ber_element   DBMS_LDAP.ber_element;
        l_vals          DBMS_LDAP.string_collection;
    BEGIN
        DBMS_LDAP.USE_EXCEPTION   := TRUE;

        l_session                 :=
            DBMS_LDAP.init (hostname => l_ldap_host, portnum => l_ldap_port);

        l_retval                  :=
            DBMS_LDAP.simple_bind_s (ld       => l_session,
                                     dn       => l_ldap_user,
                                     passwd   => l_ldap_passwd);

        l_attrs (1)               := 'sAMAccountName';
        l_attrs (2)               := 'employeeNumber';
        l_attrs (3)               := 'displayName';
        l_attrs (4)               := 'description';
        l_attrs (5)               := 'telephoneNumber';
        l_attrs (6)               := 'facsimileTelephoneNumber';
        l_attrs (7)               := 'department';
        l_attrs (8)               := 'company';
        l_attrs (9)               := 'employeeID';
        l_attrs (10)              := 'streetAddress';
        l_attrs (11)              := 'mail';
        l_attrs (12)              := 'c';
        l_attrs (13)              := 'l';
        l_attrs (14)              := 'postalCode';
        l_attrs (15)              := 'memberOf';
        l_attrs (16)              := 'extensionAttribute8';
        l_attrs (17)              := 'extensionAttribute9';
        /*l_attrs(1)  := 'sAMAccountName';
        l_attrs(2) := 'memberOf';*/

        l_retval                  :=
            DBMS_LDAP.search_s (ld => l_session, base => l_ldap_base, scope => DBMS_LDAP.SCOPE_SUBTREE, filter => l_filter, attrs => l_attrs, attronly => 0
                                , res => l_message);

        IF DBMS_LDAP.count_entries (ld => l_session, msg => l_message) > 0
        THEN
            l_entry      :=
                DBMS_LDAP.first_entry (ld => l_session, msg => l_message);


           <<entry_loop>>
            v_entry_id   := 0;

            WHILE l_entry IS NOT NULL
            LOOP
                v_entry_id   := v_entry_id + 1;
                -- Get all Attributes of the Entry
                l_attr_name   :=
                    DBMS_LDAP.first_attribute (ld          => l_session,
                                               ldapentry   => l_entry,
                                               ber_elem    => l_ber_element);

               <<attributes_loop>>
                WHILE l_attr_name IS NOT NULL
                --AND l_attr_name  IN('sAMAccountName','employeeNumber','displayName')
                LOOP
                    l_vals           :=
                        DBMS_LDAP.get_values (ld          => l_session,
                                              ldapentry   => l_entry,
                                              attr        => l_attr_name);


                   <<values_loop>>
                    user_row.login   := NULL;

                    FOR i IN l_vals.FIRST .. l_vals.LAST
                    LOOP
                        IF l_attr_name = 'sAMAccountName'
                        THEN
                            user_row.login   := l_vals (i);
                        ELSE
                            user_row.login   := NULL;
                        END IF;

                        user_row.id     := v_entry_id;
                        user_row.attr   := l_attr_name;
                        user_row.val    := l_vals (i);
                        PIPE ROW (user_row);
                    END LOOP values_loop;

                    l_attr_name      :=
                        DBMS_LDAP.next_attribute (
                            ld          => l_session,
                            ldapentry   => l_entry,
                            ber_elem    => l_ber_element);
                END LOOP attibutes_loop;

                l_entry      :=
                    DBMS_LDAP.next_entry (ld => l_session, msg => l_entry);
            END LOOP entry_loop;
        END IF;

        -- Close Connection to LDAP Server
        l_retval                  := DBMS_LDAP.unbind_s (ld => l_session);

        RETURN;
    END;
END XXD_ONT_LDAP_UTILS_PKG;
/
