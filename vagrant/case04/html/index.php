<?php
    header('Content-Type: text/plain');
    echo "Server IP: ".$_SERVER['SERVER_ADDR'];
    echo "\nClient IP: ".$_SERVER['REMOTE_ADDR'];
?>