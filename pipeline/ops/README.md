# Production VPN namespaces

The pipeline host keeps one WireGuard interface per Surfshark location in an
isolated Linux network namespace. Only `yt-dlp` enters these namespaces; the
pipeline HTTP server and the rest of the host retain their normal routing.

## Host files

Private Surfshark profiles are not committed. Install each downloaded profile
as root with mode 0600 using this naming convention:

```text
/etc/wireguard/surfshark-cy-nic.conf
/etc/wireguard/surfshark-gr-ath.conf
/etc/wireguard/surfshark-no-osl.conf
/etc/wireguard/surfshark-co-bog.conf
```

Install the non-secret runtime files from this directory:

```sh
sudo install -m 0755 surfshark-wg-netns /usr/local/sbin/surfshark-wg-netns
sudo install -m 0644 surfshark-wg-netns@.service /etc/systemd/system/
sudo install -d -m 0755 /etc/systemd/system/langlets-pipeline.service.d
sudo install -m 0644 langlets-pipeline-vpn.conf \
  /etc/systemd/system/langlets-pipeline.service.d/vpn-namespaces.conf
sudo install -m 0644 langlets-pipeline-ytdlp.conf \
  /etc/systemd/system/langlets-pipeline.service.d/yt-dlp.conf
```

Ubuntu needs `wireguard-tools`. The dedicated yt-dlp environment is installed
without replacing the host Python packages:

```sh
uv venv --clear /home/ynon/.local/share/langlets-ytdlp
uv pip install --python /home/ynon/.local/share/langlets-ytdlp/bin/python \
  'yt-dlp==2026.8.19' 'curl-cffi==0.16.3' 'yt-dlp-ejs==0.8.0'
```

Enable the four interfaces and reload the pipeline:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now \
  surfshark-wg-netns@cy-nic.service \
  surfshark-wg-netns@gr-ath.service \
  surfshark-wg-netns@no-osl.service \
  surfshark-wg-netns@co-bog.service
sudo systemctl restart langlets-pipeline.service
```

`pipeline/.env` selects them with:

```dotenv
YTDLP_NETWORK_NAMESPACE=cy-nic-wg,gr-ath-wg,no-osl-wg,co-bog-wg
```

Check a tunnel from inside its namespace:

```sh
sudo ip netns exec cy-nic-wg wg show wg-cy-nic
sudo ip netns exec cy-nic-wg curl -4 https://ifconfig.me/ip
```

The WireGuard interface is created on the host before it is moved. Its
encrypted UDP socket therefore retains the host's route, while the cleartext
interface lives in a namespace with no fallback interface. Do not replace this
with `ip netns exec ... wg-quick up`: a newly created interface inside the
isolated namespace has no underlying route by which to reach its VPN endpoint.
