class Sumo < Formula
  desc "Simulation of Urban Mobility"
  homepage "https://sourceforge.net/projects/sumo/"
  url "https://downloads.sourceforge.net/project/sumo/sumo/version%200.30.0/sumo-src-0.30.0.tar.gz"
  sha256 "2f0825507d756979658061847f47c5d91ec2e5c07e7ebd8839a31ab08ecde742"
  revision 1

  bottle do
    cellar :any
    sha256 "0ed8798125d5fed177a4d3f278d3069aebef4aa366c1c99a678cce6281a52ced" => :sierra
    sha256 "a72de682dca3587260c6a37ee4179d2b6bb1d0d6d49581312125ef3ded73698d" => :el_capitan
    sha256 "73e54d95f5e799f4b3752308d84afff457fc3b966ae8d9c256d73a0a9071e900" => :yosemite
  end

  option "with-test", "Enable additional build-time checking"

  deprecated_option "with-check" => "with-test"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on :x11
  depends_on "xerces-c"
  depends_on "libpng"
  depends_on "jpeg"
  depends_on "libtiff"
  depends_on "proj"
  depends_on "gdal"
  depends_on "fox"
  depends_on :python

  resource "gtest" do
    url "https://github.com/google/googletest/archive/release-1.7.0.tar.gz"
    sha256 "f73a6546fdf9fce9ff93a5015e0333a8af3062a152a9ad6bcb772c96687016cc"
  end

  resource "TextTest" do
    url "https://pypi.python.org/packages/source/T/TextTest/TextTest-3.28.2.zip"
    sha256 "2343b59425da2f24e3f9bea896e212e4caa370786c0a71312a4d9bd90ce1033b"
  end

  def install
    resource("gtest").stage do
      system "autoreconf", "-fvi"
      system "./configure"
      system "make"
      buildpath.install "../googletest-release-1.7.0"
    end

    ENV["LDFLAGS"] = "-lpython" # My compilation fails without this flag, despite :python dependency.
    ENV.append_to_cflags "-I#{buildpath}/googletest-release-1.7.0/include"

    system "./configure", "--disable-debug",
                          "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}",
                          "--with-python",
                          "--with-gtest-config=googletest-release-1.7.0/scripts/gtest-config"

    system "make", "install"

    # Copy tools/ and data/ to cellar. These contain some Python modules that have no setup.py.
    prefix.install "tools", "data"

    # Basic tests, they are fast, so execute them always.
    system "unittest/src/sumo-unittest"

    # Additional tests. These take more time, and some fail on my machine...
    if build.with? "test"
      ENV.prepend_create_path "PYTHONPATH", buildpath/"vendor/lib/python2.7/site-packages"
      resource("TextTest").stage { Language::Python.setup_install "python", buildpath/"vendor" }
      ENV.prepend_create_path "PATH", buildpath/"vendor/bin"
      system "tests/runTests.sh", "-l", "-zen", "-b", "homebrew-compilation-check"
    end

    rm bin/"sumo-unittest"
  end

  def caveats; <<-EOS.undent
    Some SUMO scripts require SUMO_HOME environmental variable:
      export SUMO_HOME=#{prefix}
    EOS
  end

  test do
    # A simple hand-made test to see if sumo compiled and linked well.

    (testpath/"hello.nod.xml").write <<-EOS.undent
      <nodes>
          <node id="1" x="-250.0" y="0.0" />
          <node id="2" x="+250.0" y="0.0" />
          <node id="3" x="+251.0" y="0.0" />
      </nodes>
    EOS

    (testpath/"hello.edg.xml").write <<-EOS.undent
      <edges>
          <edge from="1" id="1to2" to="2" />
          <edge from="2" id="out" to="3" />
      </edges>
    EOS

    system "#{bin}/netconvert", "--node-files=#{testpath}/hello.nod.xml", "--edge-files=#{testpath}/hello.edg.xml", "--output-file=#{testpath}/hello.net.xml"

    (testpath/"hello.rou.xml").write <<-EOS.undent
      <routes>
          <vType accel="1.0" decel="5.0" id="Car" length="2.0" maxSpeed="100.0" sigma="0.0" />
          <route id="route0" edges="1to2 out"/>
          <vehicle depart="1" id="veh0" route="route0" type="Car" />
      </routes>
    EOS

    (testpath/"hello.sumocfg").write <<-EOS.undent
      <configuration>
          <input>
              <net-file value="hello.net.xml"/>
              <route-files value="hello.rou.xml"/>
          </input>
          <time>
              <begin value="0"/>
              <end value="10000"/>
          </time>
      </configuration>
    EOS

    system "#{bin}/sumo", "-c", "hello.sumocfg"
  end
end
