class Etcd < Formula
  desc "Key value store for shared configuration and service discovery"
  homepage "https://github.com/etcd-io/etcd"
  url "https://github.com/etcd-io/etcd.git",
    :tag      => "v3.3.14",
    :revision => "5cf5d88a18aeaf31afd8a29f495bb4e70ee13997"
  head "https://github.com/etcd-io/etcd.git"

  bottle do
    cellar :any_skip_relocation
    sha256 "dc939db1914bdb4d33415167e8fec7dea1db3dfa2a2e4ba50ea838390dd9b0ce" => :mojave
    sha256 "9b59dc119032209a8e80210249499851454ec632af31caf4ffde75f4417fb91c" => :high_sierra
    sha256 "ce02b5fd4fc9419d2c83628b384c7852249a873e8851d669250e85fd01b97590" => :sierra
    sha256 "6955997c4e41f3e47c891d30fdcc9250a98d73d4a8af9d843783f08ece040178" => :x86_64_linux
  end

  depends_on "go" => :build

  def install
    ENV["GO111MODULE"] = "on"
    ENV["GOPATH"] = buildpath

    dir = buildpath/"src/github.com/etcd-io/etcd"
    dir.install buildpath.children

    cd dir do
      system "go", "build", "-mod", "vendor", "-ldflags", "-X main.version=#{version}", "-o", bin/"etcd"
      system "go", "build", "-mod", "vendor", "-ldflags", "-X main.version=#{version}", "-o", bin/"etcdctl"
      prefix.install_metafiles
    end
  end

  plist_options :manual => "etcd"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>KeepAlive</key>
        <dict>
          <key>SuccessfulExit</key>
          <false/>
        </dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/etcd</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>WorkingDirectory</key>
        <string>#{var}</string>
      </dict>
    </plist>
  EOS
  end

  test do
    begin
      test_string = "Hello from brew test!"
      etcd_pid = fork do
        exec bin/"etcd", "--force-new-cluster", "--data-dir=#{testpath}"
      end
      # sleep to let etcd get its wits about it
      sleep 10
      etcd_uri = "http://127.0.0.1:2379/v2/keys/brew_test"
      system "curl", "--silent", "-L", etcd_uri, "-XPUT", "-d", "value=#{test_string}"
      curl_output = shell_output("curl --silent -L #{etcd_uri}")
      response_hash = JSON.parse(curl_output)
      assert_match(test_string, response_hash.fetch("node").fetch("value"))
    ensure
      # clean up the etcd process before we leave
      Process.kill("HUP", etcd_pid)
    end
  end
end
