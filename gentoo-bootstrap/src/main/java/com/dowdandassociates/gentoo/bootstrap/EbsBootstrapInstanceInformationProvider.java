
package com.dowdandassociates.gentoo.bootstrap;

import com.amazonaws.services.ec2.model.Instance;
import com.amazonaws.services.ec2.model.Volume;

import com.google.common.base.Optional;
import com.google.common.base.Supplier;
import com.google.common.base.Suppliers;

import com.google.inject.Inject;
import com.google.inject.Provider;
import com.google.inject.name.Named;

import com.netflix.governator.annotations.Configuration;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class EbsBootstrapInstanceInformationProvider implements Provider<BootstrapInstanceInformation>
{
    private static Logger log = LoggerFactory.getLogger(EbsBootstrapInstanceInformationProvider.class);

    private Optional<Instance> instance;
    private Optional<Volume> volume;
    private BlockDeviceInformation device;

    @Inject
    public EbsBootstrapInstanceInformationProvider(
            @Named("Bootstrap Instance") Optional<Instance> instance,
            @Named("Bootstrap Volume") Optional<Volume> volume,
            BlockDeviceInformation device)
    {
        this.instance = instance;
        this.volume = volume;
        this.device = device;
    }

    public BootstrapInstanceInformation get()
    {
        // TODO: attach volume

        return new BootstrapInstanceInformation().
                withInstance(instance).
                withVolume(volume);
    }

}
