FROM theypsilon/quartus-lite-c5:17.0.docker0
WORKDIR /project
ADD . /project
RUN /opt/intelFPGA_lite/quartus/bin/quartus_sh --flow compile Arcade-RallyX.qsf
CMD cat /project/output_files/Arcade-RallyX.rbf
