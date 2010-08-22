library(ggplot2)

df = read.csv("D:\\results.csv", header=T)

p_mean_len = qplot(t, mean_len, data=df, geom="line", xlab="Time", ylab="Mean Length", main="Mean Length")
p_total_len = qplot(t, total_len, data=df, geom="line", xlab="Time", ylab="Total Length", main="Total Length")

# Arrange and display the plots into a 2x1 grid
arrange(p_mean_len,p_total_len,ncol=1)