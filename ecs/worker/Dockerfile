FROM rockylinux:9

# Install system dependencies
RUN yum update -y
RUN yum install -y epel-release
RUN yum install -y gcc
RUN yum install -y netcdf netcdf-fortran netcdf-fortran-devel netcdf-openmpi
RUN yum install -y git cmake

# Install UV by copying the binaries directly from the official image
COPY --from=ghcr.io/astral-sh/uv:0.8.14 /uv /uvx /bin/
RUN uv python install 3.11

RUN git clone https://github.com/NGWPC/t-route.git
WORKDIR "/t-route/"
RUN git checkout pi-7-NGWPC-6258

RUN ln -s /usr/lib64/gfortran/modules/netcdf.mod /usr/include/openmpi-x86_64/netcdf.mod || echo "NetCDF module link creation failed but continuing"

# Create venv and set environment to use it
RUN uv venv --python 3.11
ENV PATH="/t-route/.venv/bin:$PATH"
ENV UV_PROJECT_ENVIRONMENT="/t-route/.venv"

# Install the main package in development mode
RUN uv pip install -e .

# Run the compiler script
RUN ./compiler.sh no-e --uv

# Install the troute-rnr package specifically
WORKDIR "/t-route/src/troute-rnr"
RUN uv pip install -e '.[iac]'

CMD ["bash", "-c", "uv run python main.py --iac --debug"]
