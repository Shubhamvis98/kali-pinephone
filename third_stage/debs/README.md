Put device specific packages here as some of the packages are not available in Kali repo.
If you're building for PinePhone then only Kernel image and headers are needed.
So, you can download the kernel image and headers from releases and put the debs here.

And if you're building for PinePhonePro then you need kernel but also need to put alsa-ucm-conf package from Mobian's repo. I mean two conflicts, not sure as i don't have a Pro.
If you only put the kernel debs here the phone will boot up, after that you can debug if there will be any issue.
