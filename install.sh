#!/bin/bash
clear;

UBUNTU_TYPES=("ubuntu-dev-server" "ubuntu-prod-server" "ubuntu-workstation");

function startScript() {
  echo " ";
  echo "   Теперь мы можем приступить к работе."
  echo " ";
  echo " * Нажми [Enter] если ты уверен в том, что стоит продолжить ";
  read -p '   или [Ctrl+C] чтобы немедленно всё это остановить...';
  bash $CONTINUESCRIPT/000-$CONTINUESCRIPT.sh;
  exit;
}

echo "   (c) (r) (tm) 1974-2016";
echo "   Aperture Science Psychoacoustics Laboratory";
echo "   ";
echo " ℹ︎ Добро пожаловать!";
echo "   Этот волшебный скрипт аккуратно подпилит все острые углы в ";
echo "   голенькой и свежеустановленной операционной системе,";
echo "   а затем обработает всё мелкой наджачкой и сварит кофе.";
echo "   ";
echo " * Сначала мы попытаемся определить ОС.";
CURRENTOSVERSION=`uname -s`
if [ $CURRENTOSVERSION = "Darwin" ]; then
  echo "   Определённо, дело происходит в OS X.";
  echo "   ❤️ ❤️ ❤️";
  CONTINUESCRIPT=osx;
elif [ $CURRENTOSVERSION = "Linux" ]; then
  echo " ℹ︎ Что это тут у нас? Похоже, Linux. ";
  echo " ";
  echo " ℹ︎ На всякий случай я предупрежу, что этот скрипт умеет допиливать";
  echo "   только Ubuntu 14.04 любой редакции (сервер там, не сервер).";
  echo " ";
  echo "   Однако, у тебя есть уникальная возможность выбрать набор действий";
  echo "   подходящий под данную машину:";
  PS3=" * Для выбора, введи циферку без скобочки и нажми [Enter]: ";
  select CONTINUESCRIPT in "${UBUNTU_TYPES[@]}"
  do
    echo " ";
    echo " * Решено: мы будем разворачивать $CONTINUESCRIPT";
    break
  done;
else
  echo " ";
  echo "   Смешно, но непонятно :-(";
  echo " × Не удалось определить операционную систему.";
  echo "   Что это вообще такое - $CURRENTOSVERSION?";
  echo " * Я ухожу.";
  exit 1;
fi;
startScript;
