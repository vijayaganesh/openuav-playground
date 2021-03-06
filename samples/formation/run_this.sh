#!/bin/bash

source /simulation/inputs/parameters/swarm.sh
source /opt/ros/kinetic/setup.bash
source ~/catkin_ws/devel/setup.bash


## Previous clean-up
rm -rf /root/src/Firmware/Tools/sitl_gazebo/models/f450-tmp-*
rm -f /root/src/Firmware/posix-configs/SITL/init/lpe/f450-tmp-*
rm -f /root/src/Firmware/launch/posix_sitl_multi_tmp.launch

## world setup #
#cp /simulation/inputs/world/empty.world /root/src/Firmware/Tools/sitl_gazebo/worlds/empty.world
#cp /simulation/inputs/models/f450-1/f450-1.sdf /root/src/Firmware/Tools/sitl_gazebo/models/f450-1/f450-1.sdf
cp /simulation/inputs/setup/posix_sitl_openuav_swarm_base.launch /root/src/Firmware/launch/posix_sitl_openuav_swarm_base.launch


rm -f /simulation/outputs/*.csv
rm -f /simulation/outputs/*.txt
echo "Setup..." >> /tmp/debug


python /simulation/inputs/setup/gen_gazebo_ros_spawn.py $num_uavs 
python /simulation/inputs/setup/gen_px4_sitl.py $num_uavs 
python /simulation/inputs/setup/gen_mavros.py $num_uavs 


sleep 1

for((i=1;i<=$num_uavs;i+=1))
do
echo "px4 posix_sitl_multi_gazebo_ros$num_uavs.launch"
    roslaunch px4 posix_sitl_multi_gazebo_ros$i.launch &> /dev/null &
echo "launching uav$i ..." >> /tmp/debug
sleep 15
done


echo "launching sitl(s)..." >> /tmp/debug
roslaunch px4 posix_sitl_multi_px4_sitl.launch &> /dev/null &
sleep 15

echo "launching mavros(s) ..." >> /tmp/debug
roslaunch px4 posix_sitl_multi_mavros.launch &> /dev/null &
sleep 10

echo "Launch UAVs" >> /tmp/debug

for((i = 0;i<$num_uavs;i+=1))
do
    python /simulation/inputs/controllers/simple_Formation.py $i $num_uavs $FOLLOW_D_GAIN &> /simulation/outputs/patroLog$i.txt &
    sleep 5
done
echo "Launch Sequencer" >> /tmp/debug
python /simulation/inputs/controllers/sequencer.py $num_uavs &> /simulation/outputs/sequencerLog.txt &

    sleep 1

roslaunch rosbridge_server rosbridge_websocket.launch ssl:=false &> /dev/null &
python /simulation/inputs/measures/measureInterRobotDistance.py $num_uavs 1 &> /dev/null &
rosrun web_video_server web_video_server _port:=80 _server_threads:=100 &> /dev/null &
tensorboard --logdir=/simulation/outputs/ --port=8008 &> /dev/null &
roslaunch opencv_apps general_contours.launch  image:=/uav_2_camera/image_raw_front debug_view:=false &> /dev/null &

echo "Measures..." >> /tmp/debug
for((i=1;i<=$num_uavs;i+=1))
do
        /usr/bin/python -u /opt/ros/kinetic/bin/rostopic echo -p /mavros$i/local_position/odom > /simulation/outputs/uav$i.csv &
done


/usr/bin/python -u /opt/ros/kinetic/bin/rostopic echo -p /measure > /simulation/outputs/measure.csv &


sleep $duration_seconds
#cat /simulation/outputs/measure.csv | awk -F',' '{sum+=$2; ++n} END { print sum/n }' > /simulation/outputs/average_measure.txt

