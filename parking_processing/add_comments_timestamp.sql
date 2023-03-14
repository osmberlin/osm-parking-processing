DO
$$
DECLARE
    rec record;
BEGIN
    FOR rec IN
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'processing'
    LOOP
        RAISE NOTICE 'Adding comment on table : %.%', rec.table_schema, rec.table_name;
        EXECUTE format('COMMENT ON TABLE %I.%I IS ''' || now() || ''';',
            rec.table_schema, rec.table_name);
    END LOOP;
END;
$$
LANGUAGE plpgsql
