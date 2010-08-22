library(ggplot2)
library(gtools)

cg <- defmacro(varname, vartext, expr={qplot(t, varname, data=df, geom="line", main=vartext, xlab="Time", ylab="") +
	scale_x_continuous(breaks=NA) + 
	theme_bw() + 
	opts(axis.title.x = theme_text(size = 10, vjust = 2, hjust = 0.6)) + 
	opts(plot.title = theme_text(size=10, face="bold", hjust=0.7)) +
	annotate("segment", x=-Inf,xend=Inf,y=-Inf,yend=-Inf,arrow=arrow())})

df = read.csv("D:\\results.csv", header=T)

p_mean_len = cg(df$mean_len, "Mean Length")
p_total_len = cg(df$total_len, "Total Length")
p_max_len = cg(df$max_len, "Max Length")
p_min_len = cg(df$min_len, "Min Length")
p_std_len = cg(df$stdev_len, "StDev Length")
p_mean_cl = cg(df$mean_closeness, "Mean Closeness")
p_std_cl = cg(df$std_closeness, "StDev Closeness")
p_def_dens = cg(df$defect_dens, "Defect Density")
p_r_score = cg(df$r_score, "NN R-score")




arrange(p_mean_len, p_total_len, p_max_len, p_min_len, p_std_len, p_mean_cl, p_std_cl, p_def_dens, p_r_score, ncol=3)

vp.layout <- function(x, y) viewport(layout.pos.row=x, layout.pos.col=y)
arrange <- function(..., nrow=NULL, ncol=NULL, as.table=FALSE) {
 dots <- list(...)
 n <- length(dots)
 if(is.null(nrow) & is.null(ncol)) { nrow = floor(n/2) ; ncol = ceiling(n/nrow)}
 if(is.null(nrow)) { nrow = ceiling(n/ncol)}
 if(is.null(ncol)) { ncol = ceiling(n/nrow)}
        ## NOTE see n2mfrow in grDevices for possible alternative
grid.newpage()
pushViewport(viewport(layout=grid.layout(nrow,ncol) ) )
 ii.p <- 1
 for(ii.row in seq(1, nrow)){
 ii.table.row <- ii.row 
 if(as.table) {ii.table.row <- nrow - ii.table.row + 1}
  for(ii.col in seq(1, ncol)){
   ii.table <- ii.p
   if(ii.p > n) break
   print(dots[[ii.table]], vp=vp.layout(ii.table.row, ii.col))
   ii.p <- ii.p + 1
  }
 }
}