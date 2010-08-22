library(ggplot2)
library(reshape)

df = read.csv("D:\\results.csv", header=T)

df <- df[,-match("z_score",names(df))]
df <- df[,-match("p_value",names(df))]
df <- df[,-match("min_len",names(df))]

names(df)

df <- subset(df, select=c(t, n, mean_len, total_len, max_len, stddev_len, mean_closeness, std_closeness, defect_dens, r_score)

m <- melt(df, id = c('t'))

m$titles <- factor(rep(c('No of dunes', 'Mean Length', 'Total Length',
     'Max Length', 'StDev Length', 'Mean Closeness', 'StDev Closeness',
     'Defect Density', 'NN R-score'), each = 4))
g <- ggplot(m, aes(x = t, y = value))
g + geom_point() + geom_line() +
     facet_wrap( ~ titles, ncol = 3, scales = 'free_y') +
	theme_bw() + ylab("") + xlab("Time") + opts(strip.background=theme_blank()) +
	scale_x_continuous(breaks=0:4, labels="") +
	opts(axis.title.x = theme_text(size = 10, vjust = 2.5, hjust = 0.5)) + 
	opts(title = "Standard DECAL results	")