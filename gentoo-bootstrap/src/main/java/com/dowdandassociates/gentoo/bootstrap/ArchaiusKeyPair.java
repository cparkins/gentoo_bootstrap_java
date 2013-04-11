
package com.dowdandassociates.gentoo.bootstrap;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.attribute.PosixFilePermissions;

import com.netflix.config.DynamicPropertyFactory;
import com.netflix.config.DynamicStringProperty;

import org.apache.commons.lang3.time.DateFormatUtils;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ArchaiusKeyPair implements KeyPair
{
    private static Logger log = LoggerFactory.getLogger(ArchaiusKeyPair.class);

    private static final String KEY_PAIR_NAME_PROPERTY = "com.dowdandassociates.gentoo.bootstrap.KeyPair.name";
    private static final String KEY_PAIR_FILE_PROPERTY = "com.dowdandassociates.gentoo.bootstrap.KeyPair.filename";

    private DynamicStringProperty name;
    private DynamicStringProperty filename;

    public ArchaiusKeyPair()
    {
        String timestamp = DateFormatUtils.formatUTC(System.currentTimeMillis(), "yyyyMMdd'T'HHmmss'Z'");
        name = DynamicPropertyFactory.getInstance().getStringProperty(KEY_PAIR_NAME_PROPERTY, "gentoo-bootstrap-" + timestamp);
        try
        {
            filename = DynamicPropertyFactory.getInstance().getStringProperty(KEY_PAIR_FILE_PROPERTY,
                    Files.createTempFile(name.get(),
                                         ".pem",
                                         PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rw-------"))).toString());
        }
        catch (IOException ioe)
        {
            log.warn("Cannot create temp file", ioe);
            filename = DynamicPropertyFactory.getInstance().getStringProperty(KEY_PAIR_FILE_PROPERTY, name.get() + ".pem");
        }
    }

    @Override
    public String getName()
    {
        return name.get();
    }

    @Override
    public String getFilename()
    {
        return filename.get();
    }
}
