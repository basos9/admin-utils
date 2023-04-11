
monact_action()
{
  logger -t $TAG -p warn "Remedy action: sudo -nu srv pm2 restart all"
  sudo -nu srv pm2 restart all
}
