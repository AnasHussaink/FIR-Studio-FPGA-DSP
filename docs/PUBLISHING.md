# Publish with GitHub Desktop

1. Extract the provided ZIP. The folder containing `README.md`, `rtl`, `software` and `docs` is the repository root.
2. In GitHub Desktop choose **File → Add local repository**, select that folder, and use **create a repository here** if Desktop says it is not a Git repository.
3. Keep the local repository path at this existing folder. Do not accidentally create a second nested project folder. If publishing into an existing repository instead, use **Show in Explorer** and copy this folder's contents into that repository.
4. Review **Changes**, enter `Add FIR Studio FPGA DSP project`, then **Commit to main**.
5. Select **Publish repository**, use `FIR-Studio-FPGA-DSP`, set visibility as desired, and publish. For an existing remote use **Push origin**.
6. On GitHub verify the README images, animated preview and video link.

Suggested description:

> Programmable 4-tap FIR DSP accelerator on Artix-7 FPGA, built in SystemVerilog with pipelined fixed-point arithmetic, UART coefficient updates, and a Python GUI for waveform visualization and hardware verification.

Suggested topics: `fpga`, `systemverilog`, `rtl-design`, `digital-signal-processing`, `fir-filter`, `fixed-point`, `pipelining`, `artix-7`, `vivado`, `uart`, `python`, `pyside6`, `pyqtgraph`, `hardware-verification`.

## Video at the top

The README already contains a locally stored animated preview linked to the MP4. All paths work after publishing without needing a known account or repository URL. A local MP4 link is not a guaranteed inline player in every Markdown renderer.

For GitHub-hosted playback, upload the MP4 through an attachment-enabled GitHub editor and use its generated asset link near the top of the README. Do not invent an asset URL. GitHub documents attachment uploads and H.264 compatibility here: https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/attaching-files . If the account rejects the size, use the smaller `demo/FIR-Studio-Web.mp4` copy.

No open-source licence has been selected on the owner's behalf. Add a licence separately if you want to grant reuse rights. The package has not been published automatically.
